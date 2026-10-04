import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

export const dynamic = 'force-dynamic';

const createThreatSchema = z.object({
  domain: z.string().min(3).transform((d) => d.toLowerCase().trim().replace(/^https?:\/\//, '').replace(/\/.*$/, '')),
  category: z.enum(['PHISHING', 'SCAM', 'MALWARE', 'CRYPTO_DRAINER', 'SUSPICIOUS']).default('PHISHING'),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).default('HIGH'),
  reason: z.string().min(3),
  source: z.string().default('ADMIN'),
});

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { searchParams } = new URL(req.url);
    const search = searchParams.get('search') || '';
    const category = searchParams.get('category');
    const severity = searchParams.get('severity');
    const page = Math.max(1, parseInt(searchParams.get('page') || '1'));
    const limit = Math.min(100, Math.max(1, parseInt(searchParams.get('limit') || '25')));
    const skip = (page - 1) * limit;

    const where: any = {};

    if (search) {
      where.OR = [
        { domain: { contains: search.toLowerCase(), mode: 'insensitive' } },
        { reason: { contains: search, mode: 'insensitive' } },
      ];
    }

    if (category && category !== 'ALL') {
      where.category = category;
    }

    if (severity && severity !== 'ALL') {
      where.severity = severity;
    }

    const [total, threats, stats] = await Promise.all([
      prisma.securityThreat.count({ where }),
      prisma.securityThreat.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.securityThreat.groupBy({
        by: ['category'],
        _count: { id: true },
      }),
    ]);

    const categoryCounts: Record<string, number> = {};
    stats.forEach((s) => {
      categoryCounts[s.category] = s._count.id;
    });

    return NextResponse.json({
      success: true,
      threats,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
      stats: categoryCounts,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to fetch threats' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const parsed = createThreatSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const { domain, category, severity, reason, source } = parsed.data;

    const threat = await prisma.securityThreat.upsert({
      where: { domain },
      create: {
        domain,
        category,
        severity,
        reason,
        source,
        isActive: true,
      },
      update: {
        category,
        severity,
        reason,
        isActive: true,
        reportedCount: { increment: 1 },
      },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'ADD_SECURITY_THREAT',
        resourceType: 'SecurityThreat',
        resourceId: threat.id,
        metadata: { domain, category, severity },
      },
    });

    return NextResponse.json({ success: true, threat }, { status: 201 });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to add threat' }, { status: 500 });
  }
}
