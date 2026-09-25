import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function GET(req: NextRequest) {
  try {
    const admin = await getAuthenticatedAdmin(req);
    if (!admin) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    return NextResponse.json({
      success: true,
      data: { user: admin },
      user: admin,
    });
  } catch (error: any) {
    console.error('Auth /me error:', error);
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
}
