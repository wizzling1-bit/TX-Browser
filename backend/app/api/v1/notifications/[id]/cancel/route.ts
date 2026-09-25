import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const notification = await prisma.notification.findUnique({ where: { id: params.id } });
  if (!notification) return NextResponse.json({ error: 'Notification not found' }, { status: 404 });

  if (notification.status === 'SENT') {
    return NextResponse.json({ error: 'Cannot cancel an already completed notification' }, { status: 400 });
  }

  const updated = await prisma.notification.update({
    where: { id: params.id },
    data: { status: 'CANCELLED' },
  });

  return NextResponse.json({ message: 'Notification cancelled successfully', notification: updated });
}
