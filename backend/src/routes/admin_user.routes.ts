import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../db/prisma.js';
import { authGuard } from '../middleware/auth.guard.js';
import { AuthService } from '../services/auth.service.js';
import { auditService } from '../services/audit.service.js';
import { z } from 'zod';

const createAdminSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(2),
  role: z.enum(['SUPER_ADMIN', 'ADMIN', 'EDITOR']).default('ADMIN'),
});

const updateAdminSchema = z.object({
  name: z.string().min(2).optional(),
  role: z.enum(['SUPER_ADMIN', 'ADMIN', 'EDITOR']).optional(),
  isActive: z.boolean().optional(),
});

export async function adminUserRoutes(app: FastifyInstance) {
  // Only SUPER_ADMIN can manage admin accounts
  app.addHook('preHandler', authGuard(['SUPER_ADMIN']));

  // GET / - List all admin users
  app.get('/', async () => {
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

    return users;
  });

  // POST / - Create admin user
  app.post('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const parsed = createAdminSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parsed.error.format() });
    }

    const { email, password, name, role } = parsed.data;

    const existing = await prisma.adminUser.findUnique({ where: { email } });
    if (existing) {
      return reply.status(409).send({ error: 'An admin user with this email already exists' });
    }

    const authService = new AuthService(prisma);
    const passwordHash = await authService.hashPassword(password);

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

    const currentAdmin = (request as any).session?.adminUser;
    await auditService.log({
      adminUserId: currentAdmin?.id,
      action: 'ADMIN_USER_CREATE',
      resourceType: 'AdminUser',
      resourceId: user.id,
      metadata: { email: user.email, role: user.role },
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return reply.status(201).send(user);
  });

  // PATCH /:id - Update admin user
  app.patch('/:id', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const parsed = updateAdminSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parsed.error.format() });
    }

    const existing = await prisma.adminUser.findUnique({ where: { id } });
    if (!existing) {
      return reply.status(404).send({ error: 'Admin user not found' });
    }

    const updated = await prisma.adminUser.update({
      where: { id },
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

    const currentAdmin = (request as any).session?.adminUser;
    await auditService.log({
      adminUserId: currentAdmin?.id,
      action: 'ADMIN_USER_UPDATE',
      resourceType: 'AdminUser',
      resourceId: id,
      metadata: parsed.data,
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return updated;
  });

  // DELETE /:id - Delete admin user
  app.delete('/:id', async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const currentAdmin = (request as any).session?.adminUser;

    if (currentAdmin?.id === id) {
      return reply.status(400).send({ error: 'Cannot delete your own admin account' });
    }

    const existing = await prisma.adminUser.findUnique({ where: { id } });
    if (!existing) {
      return reply.status(404).send({ error: 'Admin user not found' });
    }

    await prisma.adminUser.delete({ where: { id } });

    await auditService.log({
      adminUserId: currentAdmin?.id,
      action: 'ADMIN_USER_DELETE',
      resourceType: 'AdminUser',
      resourceId: id,
      ipAddress: request.ip,
      userAgent: request.headers['user-agent'],
    });

    return { message: 'Admin user deleted successfully' };
  });
}
