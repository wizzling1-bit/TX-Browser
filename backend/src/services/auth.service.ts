import argon2 from 'argon2';
import { PrismaClient, AdminRole } from '@prisma/client';
import { prisma as defaultPrisma } from '../db/prisma.js';
import { AuditService, auditService as defaultAuditService } from './audit.service.js';

export interface AdminSessionUser {
  id: string;
  email: string;
  name: string;
  role: AdminRole;
}

export class AuthService {
  private audit: AuditService;

  constructor(
    private db: PrismaClient = defaultPrisma,
    audit?: AuditService
  ) {
    this.audit = audit ?? new AuditService(db);
  }

  /**
   * Hashes password using OWASP-recommended Argon2id settings.
   */
  async hashPassword(password: string): Promise<string> {
    return argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: 65536,
      timeCost: 3,
      parallelism: 4,
    });
  }

  /**
   * Verifies plaintext password against Argon2id hash.
   */
  async verifyPassword(hash: string, plain: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, plain);
    } catch {
      return false;
    }
  }

  /**
   * Performs credential verification, account lockout check, and audit logging.
   */
  async login(
    email: string,
    plainPassword: string,
    ipAddress?: string,
    userAgent?: string
  ): Promise<AdminSessionUser> {
    const user = await this.db.adminUser.findUnique({
      where: { email: email.toLowerCase().trim() },
    });

    if (!user || !user.isActive) {
      await this.audit.recordLog({
        action: 'FAILED_LOGIN_UNKNOWN_USER',
        resourceType: 'AUTH',
        metadata: { attemptedEmail: email },
        ipAddress,
        userAgent,
      });
      throw new Error('Invalid credentials or account locked');
    }

    // Check account lockout
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      const remainingMinutes = Math.ceil(
        (user.lockedUntil.getTime() - Date.now()) / (60 * 1000)
      );
      await this.audit.recordLog({
        adminUserId: user.id,
        action: 'LOGIN_ATTEMPT_LOCKED_ACCOUNT',
        resourceType: 'AUTH',
        metadata: { remainingMinutes },
        ipAddress,
        userAgent,
      });
      throw new Error(
        `Account is temporarily locked. Try again in ${remainingMinutes} minutes.`
      );
    }

    const isValid = await this.verifyPassword(user.passwordHash, plainPassword);

    if (!isValid) {
      const newFailedAttempts = user.failedAttempts + 1;
      const willLock = newFailedAttempts >= 5;
      const lockedUntil = willLock ? new Date(Date.now() + 15 * 60 * 1000) : null;

      await this.db.adminUser.update({
        where: { id: user.id },
        data: {
          failedAttempts: newFailedAttempts,
          lockedUntil,
        },
      });

      await this.audit.recordLog({
        adminUserId: user.id,
        action: willLock ? 'ACCOUNT_LOCKED_FAILED_ATTEMPTS' : 'FAILED_LOGIN_BAD_PASSWORD',
        resourceType: 'AUTH',
        metadata: { failedAttempts: newFailedAttempts, locked: willLock },
        ipAddress,
        userAgent,
      });

      throw new Error('Invalid credentials or account locked');
    }

    // Success: Reset failed attempts and update last login
    await this.db.adminUser.update({
      where: { id: user.id },
      data: {
        failedAttempts: 0,
        lockedUntil: null,
        lastLoginAt: new Date(),
      },
    });

    await this.audit.recordLog({
      adminUserId: user.id,
      action: 'LOGIN',
      resourceType: 'AUTH',
      ipAddress,
      userAgent,
    });

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
    };
  }

  /**
   * Logs out admin and records audit event.
   */
  async logout(adminUserId?: string, ipAddress?: string, userAgent?: string) {
    if (adminUserId) {
      await this.audit.recordLog({
        adminUserId,
        action: 'LOGOUT',
        resourceType: 'AUTH',
        ipAddress,
        userAgent,
      });
    }
  }
}

export const authService = new AuthService();
