import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { dispatchNotification } from '@/lib/fcm';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  // Optional cron authorization header validation
  const authHeader = req.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized cron trigger' }, { status: 401 });
  }

  const now = new Date();

  // Find all scheduled notifications ready to be sent
  const scheduledNotifications = await prisma.notification.findMany({
    where: {
      status: 'SCHEDULED',
      scheduledAt: { lte: now },
    },
    take: 10,
  });

  const results: Array<{ id: string; success: boolean; error?: string }> = [];

  for (const notif of scheduledNotifications) {
    try {
      await dispatchNotification(notif.id);
      results.push({ id: notif.id, success: true });
    } catch (err: any) {
      console.error(`Error processing scheduled notification ${notif.id}:`, err);
      results.push({ id: notif.id, success: false, error: err?.message });
    }
  }

  return NextResponse.json({
    timestamp: now.toISOString(),
    processedCount: scheduledNotifications.length,
    results,
  });
}
