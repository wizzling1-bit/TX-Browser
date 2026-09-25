import fastify, { FastifyInstance } from 'fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import cookie from '@fastify/cookie';
import session from '@fastify/session';
import rateLimit from '@fastify/rate-limit';
import { env } from './config/env.js';
import { prisma } from './db/prisma.js';

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

  // 5. Health & Readiness Probes
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

// Start server if executed directly
if (process.argv[1]?.endsWith('server.ts') || process.argv[1]?.endsWith('server.js')) {
  buildServer().then(async (app) => {
    try {
      await app.listen({ port: env.PORT, host: '0.0.0.0' });
      app.log.info(`TX Browser Notification Backend listening on port ${env.PORT}`);
    } catch (err) {
      app.log.error(err);
      process.exit(1);
    }
  });
}
