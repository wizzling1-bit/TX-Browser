import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const { audienceType, audienceConfig } = body || {};

    if (audienceType === 'ALL_USERS') {
      const count = await prisma.deviceInstallation.count({
        where: { isActive: true, notificationPermission: { not: 'denied' } },
      });
      return NextResponse.json({ audienceType, estimatedReach: count });
    }

    if (audienceType === 'TOPIC') {
      const topic = audienceConfig?.topic || 'tx_all';
      let count = await prisma.deviceTopic.count({
        where: {
          topic,
          device: { isActive: true, notificationPermission: { not: 'denied' } },
        },
      });
      if (count === 0) {
        count = await prisma.deviceInstallation.count({
          where: { isActive: true, notificationPermission: { not: 'denied' } },
        });
      }
      return NextResponse.json({ audienceType, topic, estimatedReach: count });
    }

    if (audienceType === 'SEGMENT') {
      const whereClause: any = {
        isActive: true,
        notificationPermission: { not: 'denied' },
      };

      if (audienceConfig?.appVersion && audienceConfig.appVersion.trim() && audienceConfig.appVersion !== 'ALL') {
        whereClause.appVersion = audienceConfig.appVersion.trim();
      }

      if (audienceConfig?.activeWithinDays && typeof audienceConfig.activeWithinDays === 'number') {
        const cutoff = new Date(Date.now() - audienceConfig.activeWithinDays * 24 * 60 * 60 * 1000);
        whereClause.lastSeenAt = { gte: cutoff };
      }

      const count = await prisma.deviceInstallation.count({
        where: whereClause,
      });

      return NextResponse.json({ audienceType, segment: audienceConfig, estimatedReach: count });
    }

    return NextResponse.json({ estimatedReach: 0 });
  } catch (err: any) {
    return NextResponse.json({ error: 'Estimation failed: ' + err?.message }, { status: 500 });
  }
}
