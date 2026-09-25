import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin, hashPassword } from '@/lib/auth';
import { z } from 'zod';

const createAdminSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(2),
  role: z.enum(['SUPER_ADMIN', 'ADMIN', 'EDITOR']).default('ADMIN'),
});

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin || admin.role !== 'SUPER_ADMIN') {
    return NextResponse.json({ error: 'Super Admin access required' }, { status: 403 });
  }

  const users = await prisma.adminUser.findMany({
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      isActive: true,
      lastLoginAt: true,
      createdAt: true,
    },
  });

  return NextResponse.json(users);
}

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin || admin.role !== 'SUPER_ADMIN') {
    return NextResponse.json({ error: 'Super Admin access required' }, { status: 403 });
  }

  try {
    const body = await req.json();
    const parsed = createAdminSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const { email, password, name, role } = parsed.data;

    const existing = await prisma.adminUser.findUnique({ where: { email } });
    if (existing) {
      return NextResponse.json({ error: 'An admin user with this email already exists' }, { status: 409 });
    }

    const passwordHash = await hashPassword(password);

    const user = await prisma.adminUser.create({
      data: {
        email,
        passwordHash,
        name,
        role,
      },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isActive: true,
        createdAt: true,
      },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'ADMIN_USER_CREATE',
        resourceType: 'AdminUser',
        resourceId: user.id,
        metadata: { email: user.email, role: user.role },
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    return NextResponse.json(user, { status: 201 });
  } catch (err: any) {
    return NextResponse.json({ error: 'Failed to create admin user: ' + err?.message }, { status: 500 });
  }
}
