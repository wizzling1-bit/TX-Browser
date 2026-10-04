import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { searchParams } = new URL(req.url);
    const status = searchParams.get('status');
    const category = searchParams.get('category');
    const search = searchParams.get('search') || '';
    const page = Math.max(1, parseInt(searchParams.get('page') || '1'));
    const limit = Math.min(100, Math.max(1, parseInt(searchParams.get('limit') || '25')));
    const skip = (page - 1) * limit;

    const where: any = {};

    if (status && status !== 'ALL') {
      where.status = status;
    }

    if (category && category !== 'ALL') {
      where.category = category;
    }

    if (search) {
      where.OR = [
        { targetUrl: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { deviceModel: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [total, feedbacks, statusStats] = await Promise.all([
      prisma.userFeedback.count({ where }),
      prisma.userFeedback.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.userFeedback.groupBy({
        by: ['status'],
        _count: { id: true },
      }),
    ]);

    const counts: Record<string, number> = {
      NEW: 0,
      IN_REVIEW: 0,
      RESOLVED: 0,
      DISMISSED: 0,
    };
    statusStats.forEach((s) => {
      counts[s.status] = s._count.id;
    });

    return NextResponse.json({
      success: true,
      feedbacks,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
      counts,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to fetch feedback' }, { status: 500 });
  }
}
