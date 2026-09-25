import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { dispatchNotification } from '@/lib/fcm';

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const notification = await prisma.notification.findUnique({ where: { id: params.id } });
  if (!notification) return NextResponse.json({ error: 'Notification not found' }, { status: 404 });

  if (notification.status === 'SENT' || notification.status === 'SENDING') {
    return NextResponse.json({ error: `Notification is already ${notification.status.toLowerCase()}` }, { status: 400 });
  }

  try {
    const result = await dispatchNotification(params.id);

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'NOTIFICATION_SEND',
        resourceType: 'Notification',
        resourceId: notification.id,
        metadata: {
          title: notification.title,
          audienceType: notification.audienceType,
          delivered: result.deliveredCount,
        },
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    return NextResponse.json({
      message: 'Notification sent successfully',
      deliveredCount: result.deliveredCount,
      failedCount: result.failedCount,
      notification: result.notification,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to dispatch notification' }, { status: 500 });
  }
}
