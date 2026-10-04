import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

export const dynamic = 'force-dynamic';

const updateThreatSchema = z.object({
  category: z.enum(['PHISHING', 'SCAM', 'MALWARE', 'CRYPTO_DRAINER', 'SUSPICIOUS']).optional(),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
  reason: z.string().min(3).optional(),
  isActive: z.boolean().optional(),
});

export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { id } = params;
    const body = await req.json();
    const parsed = updateThreatSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const updated = await prisma.securityThreat.update({
      where: { id },
      data: parsed.data,
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'UPDATE_SECURITY_THREAT',
        resourceType: 'SecurityThreat',
        resourceId: id,
        metadata: parsed.data,
      },
    });

    return NextResponse.json({ success: true, threat: updated });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to update threat' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { id } = params;
    const deleted = await prisma.securityThreat.delete({
      where: { id },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'DELETE_SECURITY_THREAT',
        resourceType: 'SecurityThreat',
        resourceId: id,
        metadata: { domain: deleted.domain },
      },
    });

    return NextResponse.json({ success: true });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to delete threat' }, { status: 500 });
  }
}
