import { PrismaClient } from '@prisma/client';
import { prisma as defaultPrisma } from '../db/prisma.js';

export class AuditService {
  constructor(private db: PrismaClient = defaultPrisma) {}

  async recordLog({
    adminUserId,
    action,
    resourceType,
    resourceId,
    metadata,
    ipAddress,
    userAgent,
  }: {
    adminUserId?: string | null;
    action: string;
    resourceType: string;
    resourceId?: string;
    metadata?: any;
    ipAddress?: string;
    userAgent?: string;
  }) {
    try {
      return await this.db.adminAuditLog.create({
        data: {
          adminUserId: adminUserId ?? null,
          action,
          resourceType,
          resourceId: resourceId ?? null,
          metadata: metadata ? (metadata as any) : undefined,
          ipAddress: ipAddress ?? null,
          userAgent: userAgent ?? null,
        },
      });
    } catch (e) {
      console.error('[AuditService] Failed to record audit log:', e);
      return null;
    }
  }

  async log(params: Parameters<AuditService['recordLog']>[0]) {
    return this.recordLog(params);
  }
}

export const auditService = new AuditService();
