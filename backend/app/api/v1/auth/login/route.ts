import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyPassword, signAdminToken, COOKIE_NAME } from '@/lib/auth';
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email('Valid email is required'),
  password: z.string().min(1, 'Password is required'),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = loginSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Invalid input', details: parsed.error.format() }, { status: 400 });
    }

    const { email, password } = parsed.data;

    const admin = await prisma.adminUser.findUnique({
      where: { email: email.toLowerCase() },
    });

    if (!admin || !admin.isActive) {
      return NextResponse.json({ error: 'Invalid email or password' }, { status: 401 });
    }

    const isValid = await verifyPassword(admin.passwordHash, password);
    if (!isValid) {
      return NextResponse.json({ error: 'Invalid email or password' }, { status: 401 });
    }

    // Update last login
    await prisma.adminUser.update({
      where: { id: admin.id },
      data: { lastLoginAt: new Date() },
    });

    const sessionPayload = {
      id: admin.id,
      email: admin.email,
      name: admin.name,
      role: admin.role as 'SUPER_ADMIN' | 'ADMIN' | 'EDITOR',
    };

    const token = signAdminToken(sessionPayload);

    // Record audit log
    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'ADMIN_LOGIN',
        resourceType: 'AdminUser',
        resourceId: admin.id,
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    const response = NextResponse.json({
      success: true,
      message: 'Logged in successfully',
      data: { user: sessionPayload },
      user: sessionPayload,
    });

    response.cookies.set(COOKIE_NAME, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60, // 7 days in seconds
      path: '/',
    });

    return response;
  } catch (error: any) {
    console.error('Login error:', error);
    const msg = error?.message || 'Internal server error during login';
    return NextResponse.json({ 
      error: msg.includes('DATABASE_URL') 
        ? 'Database configuration missing. Please set DATABASE_URL in Vercel Environment Variables.' 
        : (error?.message || 'Internal server error during login') 
    }, { status: 500 });
  }
}
