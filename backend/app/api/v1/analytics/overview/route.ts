import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const fourteenDaysAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);

  const [
    totalCampaigns,
    sentCampaigns,
    scheduledCampaigns,
    totalDeliveries,
    failedDeliveries,
    openedDeliveries,
    typeDistribution,
    recentDeliveries,
    topCampaigns,
  ] = await Promise.all([
    prisma.notification.count(),
    prisma.notification.count({ where: { status: 'SENT' } }),
    prisma.notification.count({ where: { status: 'SCHEDULED' } }),
    prisma.notificationDelivery.count({ where: { status: { in: ['SENT', 'OPENED'] } } }),
    prisma.notificationDelivery.count({ where: { status: 'FAILED' } }),
    prisma.notificationDelivery.count({ where: { status: 'OPENED' } }),
    prisma.notification.groupBy({
      by: ['notificationType'],
      _count: { id: true },
    }),
    prisma.notificationDelivery.findMany({
      where: { createdAt: { gte: fourteenDaysAgo } },
      select: { createdAt: true, status: true },
    }),
    prisma.notification.findMany({
      where: { status: 'SENT' },
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: {
        _count: {
          select: { deliveries: true },
        },
      },
    }),
  ]);

  const dailyMap: Record<string, { date: string; sent: number; opened: number }> = {};
  for (let i = 0; i < 14; i++) {
    const d = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
    const key = d.toISOString().split('T')[0];
    dailyMap[key] = { date: key, sent: 0, opened: 0 };
  }

  for (const d of recentDeliveries) {
    const key = d.createdAt.toISOString().split('T')[0];
    if (dailyMap[key]) {
      if (d.status === 'SENT' || d.status === 'OPENED') dailyMap[key].sent++;
      if (d.status === 'OPENED') dailyMap[key].opened++;
    }
  }

  const dailyTrend = Object.values(dailyMap).sort((a, b) => a.date.localeCompare(b.date));

  const overallOpenRate =
    totalDeliveries > 0 ? Number(((openedDeliveries / totalDeliveries) * 100).toFixed(1)) : 0;

  return NextResponse.json({
    summary: {
      totalCampaigns,
      sentCampaigns,
      scheduledCampaigns,
      totalDeliveries,
      failedDeliveries,
      openedDeliveries,
      overallOpenRate,
    },
    dailyTrend,
    typeDistribution: typeDistribution.map((t) => ({
      type: t.notificationType,
      count: t._count.id,
    })),
    topCampaigns: topCampaigns.map((c) => ({
      id: c.id,
      title: c.title,
      type: c.notificationType,
      totalDeliveries: c._count.deliveries,
    })),
  });
}
