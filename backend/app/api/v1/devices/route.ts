import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const url = new URL(req.url);
  const page = Math.max(1, parseInt(url.searchParams.get('page') || '1', 10));
  const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get('limit') || '20', 10)));
  const skip = (page - 1) * limit;

  const permission = url.searchParams.get('permission');
  const appVersion = url.searchParams.get('appVersion');
  const isActive = url.searchParams.get('isActive');
  const search = url.searchParams.get('search');

  const where: any = {};

  if (permission && permission !== 'ALL') {
    where.notificationPermission = permission;
  }

  if (appVersion) {
    where.appVersion = appVersion;
  }

  if (isActive !== null && isActive !== undefined) {
    where.isActive = isActive === 'true';
  }

  if (search) {
    where.OR = [
      { installationId: { contains: search, mode: 'insensitive' } },
      { deviceModel: { contains: search, mode: 'insensitive' } },
      { androidVersion: { contains: search, mode: 'insensitive' } },
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

  return NextResponse.json({
    items: formattedDevices,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  });
}
