import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const device = await prisma.deviceInstallation.findFirst({
    where: {
      OR: [
        { id: params.id },
        { installationId: params.id },
      ],
    },
    include: {
      topics: { select: { topic: true, createdAt: true } },
      deliveries: {
        orderBy: { createdAt: 'desc' },
        take: 50,
        include: {
          notification: {
            select: { id: true, title: true, notificationType: true },
          },
        },
      },
    },
  });

  if (!device) {
    return NextResponse.json({ error: 'Device installation not found' }, { status: 404 });
  }

  return NextResponse.json(device);
}
