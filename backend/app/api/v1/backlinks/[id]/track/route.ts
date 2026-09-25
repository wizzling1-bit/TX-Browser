import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const updated = await prisma.campaignBacklink.update({
      where: { id: params.id },
      data: {
        clickCount: { increment: 1 },
      },
    });

    return NextResponse.json({ success: true, clickCount: updated.clickCount });
  } catch {
    return NextResponse.json({ error: 'Backlink not found' }, { status: 404 });
  }
}
