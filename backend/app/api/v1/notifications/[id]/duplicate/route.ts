import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const source = await prisma.notification.findUnique({ where: { id: params.id } });
  if (!source) return NextResponse.json({ error: 'Notification not found' }, { status: 404 });

  const copy = await prisma.notification.create({
    data: {
      title: `${source.title} (Copy)`,
      body: source.body,
      imageUrl: source.imageUrl,
      notificationType: source.notificationType,
      destinationType: source.destinationType,
      destinationValue: source.destinationValue,
      audienceType: source.audienceType,
      audienceConfig: source.audienceConfig as any,
      status: 'DRAFT',
      createdById: admin.id,
    },
  });

  return NextResponse.json(copy, { status: 201 });
}
