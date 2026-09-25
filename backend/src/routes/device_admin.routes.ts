import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../db/prisma.js';
import { authGuard } from '../middleware/auth.guard.js';

export async function deviceAdminRoutes(app: FastifyInstance) {
  app.addHook('preHandler', authGuard(['SUPER_ADMIN', 'ADMIN']));

  // GET / - List devices with search, filtering, and pagination
  app.get('/', async (request: FastifyRequest<{
    Querystring: {
      search?: string;
      permission?: string;
      appVersion?: string;
      isActive?: string;
      page?: string;
      limit?: string;
    };
  }>) => {
    const page = Math.max(1, parseInt(request.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(request.query.limit || '20', 10)));
    const skip = (page - 1) * limit;

    const where: any = {};

    if (request.query.permission && request.query.permission !== 'ALL') {
      where.notificationPermission = request.query.permission;
    }

    if (request.query.appVersion) {
      where.appVersion = request.query.appVersion;
    }

    if (request.query.isActive !== undefined) {
      where.isActive = request.query.isActive === 'true';
    }

    if (request.query.search) {
      const q = request.query.search;
      where.OR = [
        { installationId: { contains: q, mode: 'insensitive' } },
        { deviceModel: { contains: q, mode: 'insensitive' } },
        { androidVersion: { contains: q, mode: 'insensitive' } },
      ];
    }

    const [total, devices] = await Promise.all([
      prisma.deviceInstallation.count({ where }),
      prisma.deviceInstallation.findMany({
        where,
        orderBy: { lastSeenAt: 'desc' },
        skip,
        take: limit,
        include: {
          topics: {
            select: { topic: true },
          },
          _count: {
            select: { deliveries: true },
          },
        },
      }),
    ]);

    const formattedDevices = devices.map((d) => ({
      ...d,
      topics: d.topics.map((t) => t.topic),
      totalDeliveries: d._count.deliveries,
    }));

    return {
      items: formattedDevices,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  });

  // GET /:installationId - Detailed device inspect
  app.get('/:installationId', async (request: FastifyRequest<{ Params: { installationId: string } }>, reply: FastifyReply) => {
    const { installationId } = request.params;

    const device = await prisma.deviceInstallation.findUnique({
      where: { installationId },
      include: {
        topics: { select: { topic: true, createdAt: true } },
        deliveries: {
          orderBy: { createdAt: 'desc' },
          take: 50,
          include: {
            notification: {
              select: { id: true, title: true, notificationType: true },
            },
          },
        },
      },
    });

    if (!device) {
      return reply.status(404).send({ error: 'Device installation not found' });
    }

    return device;
  });
}
