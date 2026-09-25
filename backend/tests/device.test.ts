import { describe, it, expect, vi, beforeEach } from 'vitest';
import { DeviceService } from '../src/services/device.service.js';
import { registerDeviceSchema, heartbeatSchema, notificationOpenSchema } from '../src/schemas/device.schema.js';

describe('Device Schema & Service Unit Tests', () => {
  let mockPrisma: any;
  let deviceService: DeviceService;

  beforeEach(() => {
    mockPrisma = {
      deviceInstallation: {
        upsert: vi.fn(),
        update: vi.fn(),
        findUnique: vi.fn(),
      },
      notificationDelivery: {
        findFirst: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
      },
    };
    deviceService = new DeviceService(mockPrisma);
  });

  describe('Zod Validation Schemas', () => {
    it('validates a correct device registration payload', () => {
      const validPayload = {
        installationId: 'c24b6e51-d419-4a0b-8d76-e17f7d1a938f',
        fcmToken: 'fcm_token_sample_abc123',
        appVersion: '1.0.4',
        buildNumber: 5,
        androidVersion: 'Android 14',
        deviceModel: 'Pixel 8 Pro',
        notificationPermission: 'granted',
      };

      const result = registerDeviceSchema.safeParse(validPayload);
      expect(result.success).toBe(true);
    });

    it('rejects invalid or empty installationId and fcmToken', () => {
      const invalidPayload = {
        installationId: 'not-a-uuid',
        fcmToken: '',
        appVersion: '',
        buildNumber: -1,
        androidVersion: '',
        deviceModel: '',
      };

      const result = registerDeviceSchema.safeParse(invalidPayload);
      expect(result.success).toBe(false);
    });

    it('validates heartbeat payload', () => {
      const validHeartbeat = {
        installationId: 'c24b6e51-d419-4a0b-8d76-e17f7d1a938f',
        appVersion: '1.0.4',
        notificationPermission: 'granted',
      };

      const result = heartbeatSchema.safeParse(validHeartbeat);
      expect(result.success).toBe(true);
    });

    it('validates notification open tracking payload', () => {
      const validOpen = {
        notificationId: '8f0a28f7-7b64-4e2b-a320-f1c5c4e743a1',
        installationId: 'c24b6e51-d419-4a0b-8d76-e17f7d1a938f',
        openedAt: new Date().toISOString(),
      };

      const result = notificationOpenSchema.safeParse(validOpen);
      expect(result.success).toBe(true);
    });
  });

  describe('DeviceService Logic', () => {
    it('upserts installation record and sets active state to true', async () => {
      const payload = {
        installationId: 'c24b6e51-d419-4a0b-8d76-e17f7d1a938f',
        fcmToken: 'new_token_123',
        appVersion: '1.0.4',
        buildNumber: 5,
        androidVersion: 'Android 14',
        deviceModel: 'Pixel 8 Pro',
        notificationPermission: 'granted' as const,
      };

      mockPrisma.deviceInstallation.upsert.mockResolvedValue({
        id: 'db-id-1',
        ...payload,
        isActive: true,
      });

      const res = await deviceService.upsertInstallation(payload);
      expect(mockPrisma.deviceInstallation.upsert).toHaveBeenCalledWith({
        where: { installationId: payload.installationId },
        create: expect.objectContaining({
          installationId: payload.installationId,
          fcmToken: payload.fcmToken,
          isActive: true,
        }),
        update: expect.objectContaining({
          fcmToken: payload.fcmToken,
          isActive: true,
        }),
      });
      expect(res.id).toBe('db-id-1');
    });

    it('records notification open event in notification_deliveries', async () => {
      mockPrisma.notificationDelivery.findFirst.mockResolvedValue(null);
      mockPrisma.notificationDelivery.create.mockResolvedValue({
        id: 'delivery-1',
        notificationId: 'notif-1',
        installationId: 'inst-1',
        status: 'OPENED',
      });

      const res = await deviceService.recordNotificationOpen({
        notificationId: 'notif-1',
        installationId: 'inst-1',
        openedAt: new Date().toISOString(),
      });

      expect(mockPrisma.notificationDelivery.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          notificationId: 'notif-1',
          installationId: 'inst-1',
          status: 'OPENED',
        }),
      });
      expect(res.status).toBe('OPENED');
    });
  });
});
