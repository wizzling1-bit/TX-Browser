import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { buildPlayStoreBacklink } from '@/lib/backlink';
import { z } from 'zod';

const createBacklinkSchema = z.object({
  title: z.string().min(1, 'Campaign title is required').max(100),
  targetUrl: z.string().min(1, 'A valid destination URL is required'),
  campaignSlug: z.string().optional().default('promo18'),
  packageName: z.string().optional().default('com.wizzling.tx_browser'),
  notes: z.string().optional().nullable(),
  isActive: z.boolean().optional().default(true),
});

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const url = new URL(req.url);
  const search = url.searchParams.get('search');
  const isActive = url.searchParams.get('isActive');

  const where: any = {};
  if (isActive !== null && isActive !== undefined) {
    where.isActive = isActive === 'true';
  }

  if (search && search.trim()) {
    const q = search.trim();
    where.OR = [
      { title: { contains: q, mode: 'insensitive' } },
      { targetUrl: { contains: q, mode: 'insensitive' } },
      { campaignSlug: { contains: q, mode: 'insensitive' } },
    ];
  }

  const backlinks = await prisma.campaignBacklink.findMany({
    where,
    orderBy: { createdAt: 'desc' },
  });

  return NextResponse.json({ success: true, data: backlinks, total: backlinks.length });
}

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const parsed = createBacklinkSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Invalid input', details: parsed.error.format() }, { status: 400 });
    }

    const { title, targetUrl, campaignSlug, packageName, notes, isActive } = parsed.data;

    const built = buildPlayStoreBacklink(targetUrl, campaignSlug, packageName);

    const record = await prisma.campaignBacklink.create({
      data: {
        title,
        targetUrl: built.targetUrl,
        campaignSlug: built.campaignSlug,
        packageName: built.packageName,
        fullBacklink: built.fullBacklink,
        deepLink: built.deepLink,
        notes: notes || null,
        isActive,
      },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'BACKLINK_CREATE',
        resourceType: 'CampaignBacklink',
        resourceId: record.id,
        metadata: { title, targetUrl: built.targetUrl, fullBacklink: built.fullBacklink },
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    return NextResponse.json({
      success: true,
      message: 'Campaign backlink saved successfully',
      data: record,
    }, { status: 201 });
  } catch (err: any) {
    console.error('Error creating backlink:', err);
    return NextResponse.json({ error: err?.message || 'Failed to save campaign backlink' }, { status: 500 });
  }
}
