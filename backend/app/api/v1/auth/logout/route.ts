import { NextRequest, NextResponse } from 'next/server';
import { COOKIE_NAME, getAuthenticatedAdmin } from '@/lib/auth';
import { prisma } from '@/lib/prisma';

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);

  if (admin) {
    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'ADMIN_LOGOUT',
        resourceType: 'AdminUser',
        resourceId: admin.id,
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});
  }

  const response = NextResponse.json({ message: 'Logged out successfully' });
  response.cookies.delete(COOKIE_NAME);
  return response;
}
