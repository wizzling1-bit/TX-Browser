import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

  const [
    totalInstallations,
    activeInstallations,
    activeLast30Days,
    permissionGranted,
    permissionDenied,
    permissionUnknown,
    topicCounts,
    appVersionBreakdown,
    androidVersionBreakdown,
  ] = await Promise.all([
    prisma.deviceInstallation.count(),
    prisma.deviceInstallation.count({ where: { isActive: true } }),
    prisma.deviceInstallation.count({ where: { isActive: true, lastSeenAt: { gte: thirtyDaysAgo } } }),
    prisma.deviceInstallation.count({ where: { isActive: true, notificationPermission: 'granted' } }),
    prisma.deviceInstallation.count({ where: { isActive: true, notificationPermission: 'denied' } }),
    prisma.deviceInstallation.count({ where: { isActive: true, notificationPermission: 'unknown' } }),
    prisma.deviceTopic.groupBy({
      by: ['topic'],
      _count: { installationId: true },
    }),
    prisma.deviceInstallation.groupBy({
      by: ['appVersion'],
      where: { isActive: true },
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
      take: 10,
    }),
    prisma.deviceInstallation.groupBy({
      by: ['androidVersion'],
      where: { isActive: true },
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
      take: 10,
    }),
  ]);

  const topics: Record<string, number> = {};
  for (const t of topicCounts) {
    topics[t.topic] = t._count.installationId;
  }

  return NextResponse.json({
    summary: {
      totalInstallations,
      activeInstallations,
      activeLast30Days,
      permissionGranted,
      permissionDenied,
      permissionUnknown,
      grantedPercentage:
        activeInstallations > 0 ? Number(((permissionGranted / activeInstallations) * 100).toFixed(1)) : 0,
    },
    topics,
    versions: {
      app: appVersionBreakdown.map((item) => ({ version: item.appVersion, count: item._count.id })),
      android: androidVersionBreakdown.map((item) => ({ version: item.androidVersion, count: item._count.id })),
    },
  });
}
