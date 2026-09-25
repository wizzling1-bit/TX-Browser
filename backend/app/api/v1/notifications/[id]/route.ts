import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

const updateNotificationSchema = z.object({
  title: z.string().min(1).max(100).optional(),
  body: z.string().min(1).max(500).optional(),
  imageUrl: z.string().url().optional().nullable().or(z.literal('')),
  notificationType: z.enum(['GENERAL', 'BROWSER_UPDATE', 'PROMOTION', 'NEW_FEATURE', 'SECURITY', 'ANNOUNCEMENT', 'MAINTENANCE']).optional(),
  destinationType: z.enum(['HOME', 'WEB_URL', 'PLAY_STORE', 'INTERNAL_SCREEN', 'NO_ACTION']).optional(),
  destinationValue: z.string().optional().nullable(),
  audienceType: z.enum(['ALL_USERS', 'SEGMENT', 'TOPIC']).optional(),
  audienceConfig: z.record(z.any()).optional().nullable(),
  scheduledAt: z.string().datetime().optional().nullable(),
});

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const notification = await prisma.notification.findUnique({
    where: { id: params.id },
    include: {
      deliveries: {
        take: 20,
        orderBy: { sentAt: 'desc' },
        include: {
          device: {
            select: { id: true, deviceModel: true, platform: true, appVersion: true },
          },
        },
      },
      jobs: true,
    },
  });

  if (!notification) {
    return NextResponse.json({ error: 'Notification not found' }, { status: 404 });
  }

  return NextResponse.json(notification);
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const existing = await prisma.notification.findUnique({ where: { id: params.id } });
  if (!existing) return NextResponse.json({ error: 'Notification not found' }, { status: 404 });

  if (existing.status === 'SENT' || existing.status === 'SENDING') {
    return NextResponse.json({ error: 'Cannot update notification that has already been dispatched' }, { status: 400 });
  }

  const body = await req.json();
  const parsed = updateNotificationSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
  }

  const data = parsed.data;
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
    where: { id: params.id },
    data: {
      title: data.title ?? existing.title,
      body: data.body ?? existing.body,
      imageUrl: data.imageUrl !== undefined ? (data.imageUrl ? data.imageUrl : null) : existing.imageUrl,
      notificationType: data.notificationType ?? existing.notificationType,
      destinationType: data.destinationType ?? existing.destinationType,
      destinationValue: data.destinationValue !== undefined ? data.destinationValue : existing.destinationValue,
      audienceType: data.audienceType ?? existing.audienceType,
      audienceConfig: data.audienceConfig !== undefined ? (data.audienceConfig as any) : existing.audienceConfig,
      scheduledAt: scheduledDate,
      status,
    },
  });

  return NextResponse.json(updated);
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const existing = await prisma.notification.findUnique({ where: { id: params.id } });
  if (!existing) return NextResponse.json({ error: 'Notification not found' }, { status: 404 });

  if (existing.status === 'SENDING') {
    return NextResponse.json({ error: 'Cannot delete notification that is actively sending' }, { status: 400 });
  }

  await prisma.notification.delete({ where: { id: params.id } });

  await prisma.adminAuditLog.create({
    data: {
      adminUserId: admin.id,
      action: 'NOTIFICATION_DELETE',
      resourceType: 'Notification',
      resourceId: params.id,
      ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
      userAgent: req.headers.get('user-agent'),
    },
  }).catch(() => {});

  return NextResponse.json({ message: 'Notification deleted successfully' });
}
