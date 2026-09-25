import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { loginSchema } from '../schemas/auth.schema.js';
import { authService } from '../services/auth.service.js';
import { requireAuth } from '../middleware/auth.guard.js';

export async function authRoutes(app: FastifyInstance, _opts: FastifyPluginOptions) {
  // POST /api/v1/auth/login
  app.post(
    '/login',
    {
      config: {
        rateLimit: {
          max: 10,
          timeWindow: '15 minutes',
        },
      },
    },
    async (request, reply) => {
      const parseResult = loginSchema.safeParse(request.body);
      if (!parseResult.success) {
        return reply.status(400).send({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Invalid email or password payload',
            details: parseResult.error.format(),
          },
        });
      }

      try {
        const user = await authService.login(
          parseResult.data.email,
          parseResult.data.password,
          request.ip,
          request.headers['user-agent']
        );

        request.session.adminUser = user;

        return reply.status(200).send({
          success: true,
          data: { user },
        });
      } catch (err: any) {
        request.log.warn({ email: parseResult.data.email, error: err.message }, 'Admin login failed');
        return reply.status(401).send({
          success: false,
          error: {
            code: 'AUTH_FAILED',
            message: err.message || 'Invalid credentials or account locked',
          },
        });
      }
    }
  );

  // POST /api/v1/auth/logout
  app.post('/logout', async (request, reply) => {
    if (request.session.adminUser) {
      await authService.logout(
        request.session.adminUser.id,
        request.ip,
        request.headers['user-agent']
      );
      await request.session.destroy();
    }
    return reply.status(200).send({
      success: true,
      message: 'Logged out successfully',
    });
  });

  // GET /api/v1/auth/me
  app.get('/me', { preHandler: [requireAuth] }, async (request, reply) => {
    return reply.status(200).send({
      success: true,
      data: {
        user: request.session.adminUser,
      },
    });
  });
}
