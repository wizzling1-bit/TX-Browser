import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../db/prisma.js';
import { authGuard } from '../middleware/auth.guard.js';
import {
  createNotificationSchema,
  updateNotificationSchema,
  queryNotificationsSchema,
} from '../schemas/notification.schema.js';
import { queueService } from '../services/queue.service.js';
import { auditService } from '../services/audit.service.js';

export async function notificationRoutes(app: FastifyInstance) {
  // All notification endpoints require authenticated admin (SUPER_ADMIN, ADMIN, or EDITOR)
  app.addHook('preHandler', authGuard(['SUPER_ADMIN', 'ADMIN', 'EDITOR']));

  // GET / - List notifications with filters & delivery counts
  app.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const query = queryNotificationsSchema.safeParse(request.query);
    if (!query.success) {
      return reply.status(400).send({ error: 'Invalid query parameters', details: query.error.format() });
    }

    const { status, type, search, page, limit } = query.data;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (status && status !== 'ALL') {
      where.status = status;
    }
    if (type && type !== 'ALL') {
      where.notificationType = type;
    }
    if (search) {
      where.OR = [
        { title: { contains: search, mode: 'insensitive' } },
        { body: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [total, notifications] = await Promise.all([
      prisma.notification.count({ where }),
      prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          createdBy: {
            select: { id: true, name: true, email: true },
          },
          _count: {
            select: {
              deliveries: true,
              jobs: true,
            },
          },
        },
      }),
    ]);

    // Aggregate delivery stats for the retrieved notifications
    const notificationIds = notifications.map((n) => n.id);
    const deliveriesGroup = await prisma.notificationDelivery.groupBy({
      by: ['notificationId', 'status'],
      where: {
        notificationId: { in: notificationIds },
      },
      _count: {
        id: true,
      },
    });

    const deliveryMap: Record<string, { sent: number; failed: number; opened: number }> = {};
    for (const d of deliveriesGroup) {
      if (!deliveryMap[d.notificationId]) {
        deliveryMap[d.notificationId] = { sent: 0, failed: 0, opened: 0 };
      }
      if (d.status === 'SENT') deliveryMap[d.notificationId].sent += d._count.id;
      if (d.status === 'FAILED') deliveryMap[d.notificationId].failed += d._count.id;
      if (d.status === 'OPENED') {
        deliveryMap[d.notificationId].sent += d._count.id;
        deliveryMap[d.notificationId].opened += d._count.id;
      }
    }

    const items = notifications.map((n) => {
      const stats = deliveryMap[n.id] || { sent: 0, failed: 0, opened: 0 };
      const openRate = stats.sent > 0 ? Number(((stats.opened / stats.sent) * 100).toFixed(1)) : 0;
      return {
        ...n,
        stats: {
          ...stats,
          openRate,
        },
      };
    });

    return {
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  });

  // GET /:id - Single notification details with delivery breakdown and jobs
  app.get('/:id', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;

    const notification = await prisma.notification.findUnique({
      where: { id },
      include: {
        createdBy: {
          select: { id: true, name: true, email: true },
        },
        jobs: {
          orderBy: { createdAt: 'desc' },
          take: 50,
        },
      },
    });

    if (!notification) {
      return reply.status(404).send({ error: 'Notification not found' });
    }

    const [totalDeliveries, sentCount, failedCount, openedCount] = await Promise.all([
      prisma.notificationDelivery.count({ where: { notificationId: id } }),
      prisma.notificationDelivery.count({ where: { notificationId: id, status: { in: ['SENT', 'OPENED'] } } }),
      prisma.notificationDelivery.count({ where: { notificationId: id, status: 'FAILED' } }),
      prisma.notificationDelivery.count({ where: { notificationId: id, status: 'OPENED' } }),
    ]);

    const openRate = sentCount > 0 ? Number(((openedCount / sentCount) * 100).toFixed(1)) : 0;

    return {
      ...notification,
      stats: {
        total: totalDeliveries,
        sent: sentCount,
        failed: failedCount,
        opened: openedCount,
        openRate,
      },
    };
  });

  // POST / - Create a new notification (DRAFT or SCHEDULED)
  app.post('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = createNotificationSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        error: 'Validation failed',
        details: parseResult.error.format(),
      });
    }

    const admin = (request as any).session?.adminUser;
    const data = parseResult.data;

    let initialStatus: 'DRAFT' | 'SCHEDULED' = 'DRAFT';
    let scheduledDate: Date | null = null;

    if (data.scheduledAt) {
      scheduledDate = new Date(data.scheduledAt);
      if (scheduledDate > new Date()) {
        initialStatus = 'SCHEDULED';
      }
    }

    const notification = await prisma.notification.create({
      data: {
        title: data.title,
        body: data.body,
        imageUrl: data.imageUrl || null,
        notificationType: data.notificationType,
        destinationType: data.destinationType,
        destinationValue: data.destinationValue || null,
        audienceType: data.audienceType,
        audienceConfig: data.audienceConfig || undefined,
        status: initialStatus,
        scheduledAt: scheduledDate,
        createdById: admin?.id || null,
      },
    });

    await auditService.log({
      adminUserId: admin?.id,
      action: 'NOTIFICATION_CREATE',
      resourceType: 'Notification',
      resourceId: notification.id,
      metadata: { title: notification.title, status: notification.status },
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return reply.status(201).send(notification);
  });

  // PUT /:id - Update notification
  app.put('/:id', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const parseResult = updateNotificationSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        error: 'Validation failed',
        details: parseResult.error.format(),
      });
    }

    const existing = await prisma.notification.findUnique({ where: { id } });
    if (!existing) {
      return reply.status(404).send({ error: 'Notification not found' });
    }

    if (['SENDING', 'SENT'].includes(existing.status)) {
      return reply.status(400).send({
        error: 'Cannot edit notification that is already sending or sent',
      });
    }

    const data = parseResult.data;
    const admin = (request as any).session?.adminUser;

    let status = existing.status;
    let scheduledDate = existing.scheduledAt;

    if (data.scheduledAt !== undefined) {
      if (data.scheduledAt) {
        scheduledDate = new Date(data.scheduledAt);
        status = scheduledDate > new Date() ? 'SCHEDULED' : 'DRAFT';
      } else {
        scheduledDate = null;
        status = 'DRAFT';
      }
    }

    const updated = await prisma.notification.update({
      where: { id },
      data: {
        title: data.title ?? existing.title,
        body: data.body ?? existing.body,
        imageUrl: data.imageUrl !== undefined ? data.imageUrl : existing.imageUrl,
        notificationType: data.notificationType ?? existing.notificationType,
        destinationType: data.destinationType ?? existing.destinationType,
        destinationValue: data.destinationValue !== undefined ? data.destinationValue : existing.destinationValue,
        audienceType: data.audienceType ?? existing.audienceType,
        audienceConfig: data.audienceConfig !== undefined ? data.audienceConfig : (existing.audienceConfig as any),
        status,
        scheduledAt: scheduledDate,
      },
    });

    await auditService.log({
      adminUserId: admin?.id,
      action: 'NOTIFICATION_UPDATE',
      resourceType: 'Notification',
      resourceId: id,
      metadata: { title: updated.title, status: updated.status },
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return updated;
  });

  // POST /:id/send - Trigger immediate delivery
  app.post('/:id/send', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const admin = (request as any).session?.adminUser;

    const notification = await prisma.notification.findUnique({ where: { id } });
    if (!notification) {
      return reply.status(404).send({ error: 'Notification not found' });
    }

    if (['QUEUED', 'SENDING', 'SENT'].includes(notification.status)) {
      return reply.status(400).send({
        error: `Notification cannot be sent because it is already ${notification.status.toLowerCase()}`,
      });
    }

    // Enqueue jobs
    await queueService.enqueueNotification(id);

    await auditService.log({
      adminUserId: admin?.id,
      action: 'NOTIFICATION_SEND',
      resourceType: 'Notification',
      resourceId: id,
      metadata: { title: notification.title, audienceType: notification.audienceType },
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    const refreshed = await prisma.notification.findUnique({ where: { id } });
    return {
      message: 'Notification enqueued for immediate delivery',
      notification: refreshed,
    };
  });

  // POST /:id/cancel - Cancel scheduled or pending notification
  app.post('/:id/cancel', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const admin = (request as any).session?.adminUser;

    const notification = await prisma.notification.findUnique({ where: { id } });
    if (!notification) {
      return reply.status(404).send({ error: 'Notification not found' });
    }

    if (notification.status === 'SENT') {
      return reply.status(400).send({ error: 'Cannot cancel an already completed notification' });
    }

    // Cancel pending jobs
    await prisma.notificationJob.updateMany({
      where: {
        notificationId: id,
        status: { in: ['PENDING', 'PROCESSING'] },
      },
      data: {
        status: 'FAILED',
        errorMessage: 'Cancelled by admin',
      },
    });

    const updated = await prisma.notification.update({
      where: { id },
      data: {
        status: 'CANCELLED',
      },
    });

    await auditService.log({
      adminUserId: admin?.id,
      action: 'NOTIFICATION_CANCEL',
      resourceType: 'Notification',
      resourceId: id,
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return {
      message: 'Notification cancelled successfully',
      notification: updated,
    };
  });

  // POST /:id/duplicate - Duplicate notification as a new draft
  app.post('/:id/duplicate', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const admin = (request as any).session?.adminUser;

    const source = await prisma.notification.findUnique({ where: { id } });
    if (!source) {
      return reply.status(404).send({ error: 'Notification not found' });
    }

    const copy = await prisma.notification.create({
      data: {
        title: `${source.title} (Copy)`,
        body: source.body,
        imageUrl: source.imageUrl,
        notificationType: source.notificationType,
        destinationType: source.destinationType,
        destinationValue: source.destinationValue,
        audienceType: source.audienceType,
        audienceConfig: source.audienceConfig as any,
        status: 'DRAFT',
        createdById: admin?.id || null,
      },
    });

    return reply.status(201).send(copy);
  });

  // DELETE /:id - Delete draft notification
  app.delete('/:id', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const admin = (request as any).session?.adminUser;

    const notification = await prisma.notification.findUnique({ where: { id } });
    if (!notification) {
      return reply.status(404).send({ error: 'Notification not found' });
    }

    if (['SENDING', 'SENT'].includes(notification.status)) {
      return reply.status(400).send({ error: 'Cannot delete notification that has already been sent' });
    }

    await prisma.notification.delete({ where: { id } });

    await auditService.log({
      adminUserId: admin?.id,
      action: 'NOTIFICATION_DELETE',
      resourceType: 'Notification',
      resourceId: id,
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return { message: 'Notification deleted successfully' };
  });
}
