import { FastifyInstance, FastifyRequest } from 'fastify';
import { prisma } from '../db/prisma.js';
import { authGuard } from '../middleware/auth.guard.js';

export async function auditRoutes(app: FastifyInstance) {
  app.addHook('preHandler', authGuard(['SUPER_ADMIN', 'ADMIN']));

  // GET / - List paginated audit logs
  app.get('/', async (request: FastifyRequest<{
    Querystring: {
      action?: string;
      resourceType?: string;
      page?: string;
      limit?: string;
    };
  }>) => {
    const page = Math.max(1, parseInt(request.query.page || '1', 10));
    const limit = Math.min(100, Math.max(1, parseInt(request.query.limit || '20', 10)));
    const skip = (page - 1) * limit;

    const where: any = {};
    if (request.query.action) {
      where.action = request.query.action;
    }
    if (request.query.resourceType) {
      where.resourceType = request.query.resourceType;
    }

    const [total, logs] = await Promise.all([
      prisma.adminAuditLog.count({ where }),
      prisma.adminAuditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          adminUser: {
            select: { id: true, name: true, email: true, role: true },
          },
        },
      }),
    ]);

    return {
      items: logs,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  });
}
