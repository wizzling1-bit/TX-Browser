import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

const updateAdminSchema = z.object({
  name: z.string().min(2).optional(),
  role: z.enum(['SUPER_ADMIN', 'ADMIN', 'EDITOR']).optional(),
  isActive: z.boolean().optional(),
});

export async function PATCH(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin || admin.role !== 'SUPER_ADMIN') {
    return NextResponse.json({ error: 'Super Admin access required' }, { status: 403 });
  }

  try {
    const body = await req.json();
    const parsed = updateAdminSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const existing = await prisma.adminUser.findUnique({ where: { id: params.id } });
    if (!existing) {
      return NextResponse.json({ error: 'Admin user not found' }, { status: 404 });
    }

    const updated = await prisma.adminUser.update({
      where: { id: params.id },
      data: parsed.data,
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isActive: true,
        updatedAt: true,
      },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'ADMIN_USER_UPDATE',
        resourceType: 'AdminUser',
        resourceId: params.id,
        metadata: parsed.data,
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    return NextResponse.json(updated);
  } catch (err: any) {
    return NextResponse.json({ error: 'Update failed: ' + err?.message }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin || admin.role !== 'SUPER_ADMIN') {
    return NextResponse.json({ error: 'Super Admin access required' }, { status: 403 });
  }

  if (admin.id === params.id) {
    return NextResponse.json({ error: 'Cannot delete your own admin account' }, { status: 400 });
  }

  const existing = await prisma.adminUser.findUnique({ where: { id: params.id } });
  if (!existing) {
    return NextResponse.json({ error: 'Admin user not found' }, { status: 404 });
  }

  await prisma.adminUser.delete({ where: { id: params.id } });

  await prisma.adminAuditLog.create({
    data: {
      adminUserId: admin.id,
      action: 'ADMIN_USER_DELETE',
      resourceType: 'AdminUser',
      resourceId: params.id,
      ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
      userAgent: req.headers.get('user-agent'),
    },
  }).catch(() => {});

  return NextResponse.json({ message: 'Admin user deleted successfully' });
}
