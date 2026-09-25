import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { buildPlayStoreBacklink } from '@/lib/backlink';
import { z } from 'zod';

const updateBacklinkSchema = z.object({
  title: z.string().min(1).max(100).optional(),
  targetUrl: z.string().min(1).optional(),
  campaignSlug: z.string().min(1).optional(),
  packageName: z.string().min(1).optional(),
  notes: z.string().optional().nullable(),
  isActive: z.boolean().optional(),
});

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const existing = await prisma.campaignBacklink.findUnique({ where: { id: params.id } });
  if (!existing) return NextResponse.json({ error: 'Campaign backlink not found' }, { status: 404 });

  return NextResponse.json({ success: true, data: existing });
}

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const existing = await prisma.campaignBacklink.findUnique({ where: { id: params.id } });
  if (!existing) return NextResponse.json({ error: 'Campaign backlink not found' }, { status: 404 });

  const body = await req.json();
  const parsed = updateBacklinkSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
  }

  const data = parsed.data;
  const newTarget = data.targetUrl !== undefined ? data.targetUrl.trim() : existing.targetUrl;
  const newSlug = data.campaignSlug !== undefined ? data.campaignSlug.trim() : existing.campaignSlug;
  const newPkg = data.packageName !== undefined ? data.packageName.trim() : existing.packageName;
  const built = buildPlayStoreBacklink(newTarget, newSlug, newPkg);

  const updated = await prisma.campaignBacklink.update({
    where: { id: params.id },
    data: {
      ...(data.title !== undefined ? { title: data.title.trim() } : {}),
      targetUrl: built.targetUrl,
      campaignSlug: built.campaignSlug,
      packageName: built.packageName,
      fullBacklink: built.fullBacklink,
      deepLink: built.deepLink,
      ...(data.notes !== undefined ? { notes: data.notes ? data.notes.trim() : null } : {}),
      ...(data.isActive !== undefined ? { isActive: Boolean(data.isActive) } : {}),
    },
  });

  return NextResponse.json({
    success: true,
    message: 'Campaign backlink updated successfully',
    data: updated,
  });
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const existing = await prisma.campaignBacklink.findUnique({ where: { id: params.id } });
  if (!existing) return NextResponse.json({ error: 'Campaign backlink not found' }, { status: 404 });

  await prisma.campaignBacklink.delete({ where: { id: params.id } });

  await prisma.adminAuditLog.create({
    data: {
      adminUserId: admin.id,
      action: 'BACKLINK_DELETE',
      resourceType: 'CampaignBacklink',
      resourceId: params.id,
      metadata: { title: existing.title, targetUrl: existing.targetUrl },
      ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
      userAgent: req.headers.get('user-agent'),
    },
  }).catch(() => {});

  return NextResponse.json({
    success: true,
    message: 'Campaign backlink deleted successfully',
  });
}
