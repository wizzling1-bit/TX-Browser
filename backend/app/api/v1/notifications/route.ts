import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

const createNotificationSchema = z.object({
  title: z.string().min(1, 'Title is required').max(100),
  body: z.string().min(1, 'Body is required').max(500),
  imageUrl: z.string().url().optional().nullable().or(z.literal('')),
  notificationType: z.enum(['GENERAL', 'BROWSER_UPDATE', 'PROMOTION', 'NEW_FEATURE', 'SECURITY', 'ANNOUNCEMENT', 'MAINTENANCE']).default('GENERAL'),
  destinationType: z.enum(['HOME', 'WEB_URL', 'PLAY_STORE', 'INTERNAL_SCREEN', 'NO_ACTION']).default('HOME'),
  destinationValue: z.string().optional().nullable(),
  audienceType: z.enum(['ALL_USERS', 'SEGMENT', 'TOPIC']).default('ALL_USERS'),
  audienceConfig: z.record(z.any()).optional().nullable(),
  scheduledAt: z.string().datetime().optional().nullable(),
});

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { searchParams } = new URL(req.url);
  const page = Math.max(1, parseInt(searchParams.get('page') || '1'));
  const limit = Math.min(100, Math.max(1, parseInt(searchParams.get('limit') || '15')));
  const status = searchParams.get('status') || undefined;
  const search = searchParams.get('search') || undefined;
  const type = searchParams.get('type') || undefined;

  const where: any = {};
  if (status && status !== 'ALL') where.status = status;
  if (type && type !== 'ALL') where.notificationType = type;
  if (search && search.trim()) {
    where.OR = [
      { title: { contains: search.trim(), mode: 'insensitive' } },
      { body: { contains: search.trim(), mode: 'insensitive' } },
    ];
  }

  const [total, items] = await Promise.all([
    prisma.notification.count({ where }),
    prisma.notification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
      include: {
        _count: {
          select: {
            deliveries: true,
          },
        },
      },
    }),
  ]);

  return NextResponse.json({
    data: items,
    pagination: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    },
  });
}

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const parsed = createNotificationSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const data = parsed.data;
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
        imageUrl: data.imageUrl ? data.imageUrl : null,
        notificationType: data.notificationType,
        destinationType: data.destinationType,
        destinationValue: data.destinationValue || null,
        audienceType: data.audienceType,
        audienceConfig: data.audienceConfig || undefined,
        status: initialStatus,
        scheduledAt: scheduledDate,
        createdById: admin.id,
      },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'NOTIFICATION_CREATE',
        resourceType: 'Notification',
        resourceId: notification.id,
        metadata: { title: notification.title, status: notification.status },
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    return NextResponse.json(notification, { status: 201 });
  } catch (err: any) {
    console.error('Error creating notification:', err);
    return NextResponse.json({ error: err?.message || 'Failed to create notification' }, { status: 500 });
  }
}
