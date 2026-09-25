import { FastifyRequest, FastifyReply } from 'fastify';
import { AdminRole } from '@prisma/client';
import { AdminSessionUser } from '../services/auth.service.js';

declare module '@fastify/session' {
  interface FastifySessionObject {
    adminUser?: AdminSessionUser;
  }
}

declare module 'fastify' {
  interface FastifySessionObject {
    adminUser?: AdminSessionUser;
  }
}

/**
 * Middleware requiring authenticated admin session.
 */
export async function requireAuth(request: FastifyRequest, reply: FastifyReply) {
  if (!request.session?.adminUser) {
    return reply.status(401).send({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Authentication required. Please log in.',
      },
    });
  }
}

/**
 * Middleware factory restricting endpoint to specified administrative roles.
 */
export function requireRole(allowedRoles: AdminRole[]) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    await requireAuth(request, reply);
    if (reply.sent) return;

    const user = request.session.adminUser!;
    if (!allowedRoles.includes(user.role)) {
      return reply.status(403).send({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: `Access denied. Requires one of: ${allowedRoles.join(', ')}`,
        },
      });
    }
  };
}
