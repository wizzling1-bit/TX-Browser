import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // 1. Calculate Campaign Clicks
    const [clickEventsCount, backlinksAgg] = await Promise.all([
      prisma.campaignClickEvent.count(),
      prisma.campaignBacklink.aggregate({
        _sum: { clickCount: true },
      }),
    ]);

    const totalBacklinkClicks = backlinksAgg._sum.clickCount || 0;
    const totalClicks = Math.max(clickEventsCount, totalBacklinkClicks);

    // 2. Calculate Installations
    const totalInstalls = await prisma.deviceInstallation.count();

    // 3. Calculate 7-Day Active Users
    const activeUsers = await prisma.deviceInstallation.count({
      where: {
        lastSeenAt: { gte: sevenDaysAgo },
      },
    });

    // 4. Calculate Retained Users (created > 7 days ago and active within last 7 days)
    const retainedUsers = await prisma.deviceInstallation.count({
      where: {
        createdAt: { lte: sevenDaysAgo },
        lastSeenAt: { gte: sevenDaysAgo },
      },
    });

    // 5. Cohort metrics based on real database records
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
    const day1Active = await prisma.deviceInstallation.count({
      where: {
        lastSeenAt: { gte: oneDayAgo },
      },
    });

    const day14Active = await prisma.deviceInstallation.count({
      where: {
        createdAt: { lte: fourteenDaysAgo },
        lastSeenAt: { gte: sevenDaysAgo },
      },
    });
    const day14Base = await prisma.deviceInstallation.count({
      where: { createdAt: { lte: fourteenDaysAgo } },
    });

    const day30Base = await prisma.deviceInstallation.count({
      where: { createdAt: { lte: thirtyDaysAgo } },
    });

    const d1Rate = totalInstalls > 0 ? Math.min(100, Math.round((day1Active / totalInstalls) * 100 * 10) / 10) : 0;
    const d7Rate = totalInstalls > 0 ? Math.min(100, Math.round((activeUsers / totalInstalls) * 100 * 10) / 10) : 0;
    const d14Rate = day14Base > 0 ? Math.min(100, Math.round((day14Active / day14Base) * 100 * 10) / 10) : 0;
    const d30Rate = day30Base > 0 ? Math.min(100, Math.round((retainedUsers / day30Base) * 100 * 10) / 10) : 0;

    // Campaign Breakdown
    const campaigns = await prisma.campaignBacklink.findMany({
      orderBy: { clickCount: 'desc' },
      take: 10,
    });

    const campaignStats = campaigns.map((camp) => {
      const clicks = camp.clickCount;
      const estimatedInstalls = totalClicks > 0 ? Math.round((clicks / totalClicks) * totalInstalls) : 0;
      const convRate = clicks > 0 ? Math.min(100, Math.round((estimatedInstalls / clicks) * 100 * 10) / 10) : 0;

      return {
        id: camp.id,
        title: camp.title,
        slug: camp.campaignSlug,
        targetUrl: camp.targetUrl,
        clicks: camp.clickCount,
        installs: estimatedInstalls,
        conversionRate: convRate,
        isActive: camp.isActive,
      };
    });

    // Conversion rates
    const clickToInstall = totalClicks > 0 ? Math.min(100, Math.round((totalInstalls / totalClicks) * 100 * 10) / 10) : 0;
    const installToActive = totalInstalls > 0 ? Math.min(100, Math.round((activeUsers / totalInstalls) * 100 * 10) / 10) : 0;
    const activeToRetained = activeUsers > 0 ? Math.min(100, Math.round((retainedUsers / activeUsers) * 100 * 10) / 10) : 0;
    const overallConversion = totalClicks > 0 ? Math.min(100, Math.round((retainedUsers / totalClicks) * 100 * 10) / 10) : 0;

    return NextResponse.json({
      success: true,
      funnel: [
        {
          stage: 1,
          name: 'Campaign Clicks',
          description: 'Unique clicks on campaign backlinks and referral URLs',
          count: totalClicks,
          dropoff: `${100 - clickToInstall}% drop-off`,
          conversion: '100%',
        },
        {
          stage: 2,
          name: 'App Installs',
          description: 'New app installations and initial device registrations',
          count: totalInstalls,
          dropoff: `${100 - installToActive}% drop-off`,
          conversion: `${clickToInstall}% of clicks`,
        },
        {
          stage: 3,
          name: 'Active Users',
          description: 'Devices actively browsing within the last 7 days',
          count: activeUsers,
          dropoff: `${100 - activeToRetained}% drop-off`,
          conversion: `${installToActive}% of installs`,
        },
        {
          stage: 4,
          name: 'Retained Core',
          description: 'Long-term active users with sustained engagement',
          count: retainedUsers,
          dropoff: 'Core baseline',
          conversion: `${activeToRetained}% of active`,
        },
      ],
      metrics: {
        totalClicks,
        totalInstalls,
        activeUsers,
        retainedUsers,
        clickToInstall,
        installToActive,
        activeToRetained,
        overallConversion,
      },
      cohortRetention: {
        day1: d1Rate,
        day7: d7Rate,
        day14: d14Rate,
        day30: d30Rate,
      },
      campaigns: campaignStats,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to calculate acquisition funnel' }, { status: 500 });
  }
}
