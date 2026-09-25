import fastify, { FastifyInstance } from 'fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import cookie from '@fastify/cookie';
import session from '@fastify/session';
import rateLimit from '@fastify/rate-limit';
import { env } from './config/env.js';
import { prisma } from './db/prisma.js';
import { deviceRoutes } from './routes/device.routes.js';
import { authRoutes } from './routes/auth.routes.js';
import { notificationRoutes } from './routes/notification.routes.js';
import { audienceRoutes } from './routes/audience.routes.js';
import { analyticsRoutes } from './routes/analytics.routes.js';
import { deviceAdminRoutes } from './routes/device_admin.routes.js';
import { auditRoutes } from './routes/audit.routes.js';
import { adminUserRoutes } from './routes/admin_user.routes.js';

export async function buildServer(): Promise<FastifyInstance> {
  const app = fastify({
    logger: {
      level: env.NODE_ENV === 'test' ? 'silent' : 'info',
      serializers: {
        req(request) {
          return {
            method: request.method,
            url: request.url,
            hostname: request.hostname,
            remoteAddress: request.ip,
          };
        },
      },
    },
    trustProxy: true,
  });

  // 1. Security Headers
  await app.register(helmet, {
    contentSecurityPolicy: env.NODE_ENV === 'production' ? undefined : false,
    crossOriginEmbedderPolicy: false,
  });

  // 2. CORS
  await app.register(cors, {
    origin: env.corsOriginsList,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  // 3. Cookies & Sessions
  await app.register(cookie);
  await app.register(session, {
    secret: env.ADMIN_SESSION_SECRET,
    cookieName: 'tx_admin_session',
    cookie: {
      secure: env.NODE_ENV === 'production',
      httpOnly: true,
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
      path: '/',
    },
  });

  // 4. Rate Limiting (Default 120 req/min for general API)
  await app.register(rateLimit, {
    max: 120,
    timeWindow: '1 minute',
  });

  // 5. API Routes
  await app.register(deviceRoutes, { prefix: '/api/v1/devices' });
  await app.register(authRoutes, { prefix: '/api/v1/auth' });
  await app.register(notificationRoutes, { prefix: '/api/v1/notifications' });
  await app.register(audienceRoutes, { prefix: '/api/v1/audiences' });
  await app.register(analyticsRoutes, { prefix: '/api/v1/analytics' });
  await app.register(deviceAdminRoutes, { prefix: '/api/v1/admin/devices' });
  await app.register(auditRoutes, { prefix: '/api/v1/admin/audit-logs' });
  await app.register(adminUserRoutes, { prefix: '/api/v1/admin/users' });

  // 6. Health & Readiness Probes
  app.get('/health', async () => {
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
    };
  });

  app.get('/ready', async (_, reply) => {
    try {
      // Ping database
      await prisma.$queryRaw`SELECT 1`;
      return { status: 'ready', database: 'connected' };
    } catch (e) {
      reply.status(503);
      return { status: 'unhealthy', database: 'disconnected', error: String(e) };
    }
  });

  return app;
}

import { queueService } from './services/queue.service.js';
import { schedulerService } from './services/scheduler.service.js';

// Start server if executed directly
if (process.argv[1]?.endsWith('server.ts') || process.argv[1]?.endsWith('server.js')) {
  buildServer().then(async (app) => {
    try {
      await app.listen({ port: env.PORT, host: '0.0.0.0' });
      app.log.info(`TX Browser Notification Backend listening on port ${env.PORT}`);

      // Start queue worker & scheduler
      queueService.startWorker(3000);
      schedulerService.startScheduler(15000);

      const shutdown = async () => {
        app.log.info('Gracefully stopping background services...');
        queueService.stopWorker();
        schedulerService.stopScheduler();
        await app.close();
        process.exit(0);
      };

      process.on('SIGINT', shutdown);
      process.on('SIGTERM', shutdown);
    } catch (err) {
      app.log.error(err);
      process.exit(1);
    }
  });
}

