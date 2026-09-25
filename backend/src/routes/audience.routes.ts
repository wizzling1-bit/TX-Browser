import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../db/prisma.js';
import { authGuard } from '../middleware/auth.guard.js';

export async function audienceRoutes(app: FastifyInstance) {
  app.addHook('preHandler', authGuard(['SUPER_ADMIN', 'ADMIN', 'EDITOR']));

  // GET /stats - Overall audience and device installation metrics
  app.get('/stats', async () => {
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

    return {
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
    };
  });

  // POST /estimate - Estimates audience size based on target configuration
  app.post('/estimate', async (request: FastifyRequest<{
    Body: {
      audienceType: 'ALL_USERS' | 'TOPIC' | 'SEGMENT';
      audienceConfig?: {
        topic?: string;
        appVersion?: string;
        minAndroidVersion?: string;
        activeWithinDays?: number;
      };
    };
  }>) => {
    const { audienceType, audienceConfig } = request.body || {};

    if (audienceType === 'ALL_USERS') {
      const count = await prisma.deviceInstallation.count({
        where: { isActive: true, notificationPermission: 'granted' },
      });
      return { audienceType, estimatedReach: count };
    }

    if (audienceType === 'TOPIC') {
      const topic = audienceConfig?.topic || 'tx_all';
      const count = await prisma.deviceTopic.count({
        where: {
          topic,
          device: { isActive: true, notificationPermission: 'granted' },
        },
      });
      return { audienceType, topic, estimatedReach: count };
    }

    if (audienceType === 'SEGMENT') {
      const whereClause: any = {
        isActive: true,
        notificationPermission: 'granted',
      };

      if (audienceConfig?.appVersion) {
        whereClause.appVersion = audienceConfig.appVersion;
      }

      if (audienceConfig?.activeWithinDays && typeof audienceConfig.activeWithinDays === 'number') {
        const cutoff = new Date(Date.now() - audienceConfig.activeWithinDays * 24 * 60 * 60 * 1000);
        whereClause.lastSeenAt = { gte: cutoff };
      }

      const count = await prisma.deviceInstallation.count({
        where: whereClause,
      });

      return { audienceType, segment: audienceConfig, estimatedReach: count };
    }

    return { estimatedReach: 0 };
  });
}
