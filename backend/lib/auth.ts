import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { cookies } from 'next/headers';
import { NextRequest } from 'next/server';
import { prisma } from './prisma';

let argon2: any = null;
try {
  argon2 = require('argon2');
} catch {
  // Argon2 native module unavailable in some serverless runtimes; bcryptjs fallback active
}

const SESSION_SECRET = process.env.ADMIN_SESSION_SECRET || process.env.JWT_SECRET || 'super_secret_cookie_session_key_min_32_chars_long_12345';
export const COOKIE_NAME = 'tx_admin_session';

export interface AdminSessionPayload {
  id: string;
  email: string;
  name: string;
  role: 'SUPER_ADMIN' | 'ADMIN' | 'EDITOR';
}

export function signAdminToken(admin: AdminSessionPayload): string {
  return jwt.sign(
    {
      id: admin.id,
      email: admin.email,
      name: admin.name,
      role: admin.role,
    },
    SESSION_SECRET,
    { expiresIn: '7d' }
  );
}

export function verifyAdminToken(token: string): AdminSessionPayload | null {
  try {
    return jwt.verify(token, SESSION_SECRET) as AdminSessionPayload;
  } catch {
    return null;
  }
}

export async function hashPassword(password: string): Promise<string> {
  if (argon2) {
    try {
      return await argon2.hash(password, {
        type: argon2.argon2id,
        memoryCost: 65536,
        timeCost: 3,
        parallelism: 4,
      });
    } catch {
      // fallback to bcrypt
    }
  }
  return bcrypt.hash(password, 10);
}

export async function verifyPassword(hash: string, plain: string): Promise<boolean> {
  try {
    if (hash.startsWith('$argon2') && argon2) {
      return await argon2.verify(hash, plain);
    }
    if (hash.startsWith('$2a$') || hash.startsWith('$2b$') || hash.startsWith('$2y$')) {
      return await bcrypt.compare(plain, hash);
    }
    // Try both as fallback
    if (argon2) {
      try {
        if (await argon2.verify(hash, plain)) return true;
      } catch {}
    }
    return await bcrypt.compare(plain, hash);
  } catch {
    return false;
  }
}

export async function getAuthenticatedAdmin(req?: NextRequest): Promise<AdminSessionPayload | null> {
  try {
    let token: string | undefined;

    if (req) {
      // 1. Check cookies in request
      token = req.cookies.get(COOKIE_NAME)?.value;

      // 2. Check Authorization Bearer header fallback
      if (!token) {
        const authHeader = req.headers.get('authorization');
        if (authHeader?.startsWith('Bearer ')) {
          token = authHeader.substring(7);
        }
      }
    } else {
      try {
        const cookieStore = cookies();
        token = cookieStore.get(COOKIE_NAME)?.value;
      } catch {
        // not in request scope
      }
    }

    if (!token) return null;

    const payload = verifyAdminToken(token);
    if (!payload) return null;

    // Verify admin is still active in database
    const admin = await prisma.adminUser.findUnique({
      where: { id: payload.id },
      select: { id: true, email: true, name: true, role: true, isActive: true },
    });

    if (!admin || !admin.isActive) return null;

    return {
      id: admin.id,
      email: admin.email,
      name: admin.name,
      role: admin.role as 'SUPER_ADMIN' | 'ADMIN' | 'EDITOR',
    };
  } catch (err) {
    console.error('getAuthenticatedAdmin error:', err);
    return null;
  }
}

export function requireRole(allowedRoles: Array<'SUPER_ADMIN' | 'ADMIN' | 'EDITOR'>) {
  return async (req: NextRequest): Promise<{ admin: AdminSessionPayload } | { error: string; status: number }> => {
    const admin = await getAuthenticatedAdmin(req);
    if (!admin) {
      return { error: 'Unauthorized: Authentication required', status: 401 };
    }
    if (!allowedRoles.includes(admin.role)) {
      return { error: 'Forbidden: Insufficient privileges', status: 403 };
    }
    return { admin };
  };
}
