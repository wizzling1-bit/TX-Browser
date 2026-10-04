import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const sinceParam = searchParams.get('since');
    const sinceDate = sinceParam ? new Date(sinceParam) : undefined;

    const where: any = {
      isActive: true,
    };

    if (sinceDate && !isNaN(sinceDate.getTime())) {
      where.updatedAt = { gte: sinceDate };
    }

    const threats = await prisma.securityThreat.findMany({
      where,
      select: {
        id: true,
        domain: true,
        category: true,
        severity: true,
        reason: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
      take: 2000,
    });

    return NextResponse.json(
      {
        success: true,
        count: threats.length,
        syncedAt: new Date().toISOString(),
        threats,
      },
      {
        headers: {
          'Cache-Control': 'public, max-age=600, stale-while-revalidate=120',
        },
      }
    );
  } catch (error: any) {
    console.error('[Security Threats API] Error:', error);
    return NextResponse.json(
      {
        success: true,
        count: 0,
        threats: [],
      },
      { status: 200 }
    );
  }
}
