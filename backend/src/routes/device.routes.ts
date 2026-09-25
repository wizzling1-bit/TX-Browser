import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import {
  registerDeviceSchema,
  heartbeatSchema,
  notificationOpenSchema,
} from '../schemas/device.schema.js';
import { deviceService } from '../services/device.service.js';

export async function deviceRoutes(app: FastifyInstance, _opts: FastifyPluginOptions) {
  // POST /api/v1/devices/register
  app.post('/register', async (request, reply) => {
    const parseResult = registerDeviceSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid device registration payload',
          details: parseResult.error.format(),
        },
      });
    }

    try {
      const installation = await deviceService.upsertInstallation(parseResult.data);
      return reply.status(200).send({
        success: true,
        data: {
          installationId: installation.installationId,
          isActive: installation.isActive,
          updatedAt: installation.updatedAt,
        },
      });
    } catch (e: any) {
      request.log.error(e, 'Failed to register device');
      return reply.status(500).send({
        success: false,
        error: {
          code: 'REGISTRATION_FAILED',
          message: 'Could not register device installation',
        },
      });
    }
  });

  // POST /api/v1/devices/heartbeat
  app.post('/heartbeat', async (request, reply) => {
    const parseResult = heartbeatSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid heartbeat payload',
          details: parseResult.error.format(),
        },
      });
    }

    try {
      await deviceService.recordHeartbeat(parseResult.data);
      return reply.status(200).send({
        success: true,
      });
    } catch (e: any) {
      request.log.warn(e, 'Device heartbeat error');
      return reply.status(200).send({
        // Return 200 with success: false so client does not retry unnecessarily
        success: false,
      });
    }
  });

  // POST /api/v1/devices/notification-open
  app.post('/notification-open', async (request, reply) => {
    const parseResult = notificationOpenSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid notification open payload',
          details: parseResult.error.format(),
        },
      });
    }

    try {
      await deviceService.recordNotificationOpen(parseResult.data);
      return reply.status(200).send({
        success: true,
      });
    } catch (e: any) {
      request.log.error(e, 'Failed to record notification open event');
      return reply.status(500).send({
        success: false,
        error: {
          code: 'TRACKING_FAILED',
          message: 'Could not record notification open',
        },
      });
    }
  });
}
