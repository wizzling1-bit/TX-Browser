import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  createNotificationSchema,
  updateNotificationSchema,
  queryNotificationsSchema,
} from '../src/schemas/notification.schema.js';

describe('Notification Schema & Admin API Unit Tests', () => {
  describe('Zod Validation for Notifications', () => {
    it('validates a correct notification creation payload', () => {
      const validPayload = {
        title: 'New Feature: AdBlock Plus',
        body: 'Browse even faster with our latest engine update.',
        imageUrl: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f',
        notificationType: 'NEW_FEATURE',
        destinationType: 'WEB_URL',
        destinationValue: 'https://txbrowser.com/features/adblock',
        audienceType: 'ALL_USERS',
      };

      const result = createNotificationSchema.safeParse(validPayload);
      expect(result.success).toBe(true);
    });

    it('rejects an insecure HTTP destination or image URL', () => {
      const insecurePayload = {
        title: 'Insecure URL Test',
        body: 'Testing http validation',
        imageUrl: 'http://insecure.com/image.png',
        notificationType: 'GENERAL',
        destinationType: 'WEB_URL',
        destinationValue: 'http://insecure.com/landing',
        audienceType: 'ALL_USERS',
      };

      const result = createNotificationSchema.safeParse(insecurePayload);
      expect(result.success).toBe(false);
      if (!result.success) {
        const issues = result.error.issues.map((i) => i.path[0]);
        expect(issues).toContain('imageUrl');
        expect(issues).toContain('destinationValue');
      }
    });

    it('rejects an empty title or body exceeding character limits', () => {
      const longTitle = 'a'.repeat(101);
      const invalidPayload = {
        title: longTitle,
        body: '',
        notificationType: 'GENERAL',
        destinationType: 'HOME',
        audienceType: 'ALL_USERS',
      };

      const result = createNotificationSchema.safeParse(invalidPayload);
      expect(result.success).toBe(false);
    });

    it('validates audience configuration for segments', () => {
      const segmentPayload = {
        title: 'Android 14 Promotion',
        body: 'Special optimization for modern devices',
        notificationType: 'PROMOTION',
        destinationType: 'PLAY_STORE',
        audienceType: 'SEGMENT',
        audienceConfig: {
          appVersion: '1.0.4',
          minAndroidVersion: '14',
          activeWithinDays: 30,
        },
      };

      const result = createNotificationSchema.safeParse(segmentPayload);
      expect(result.success).toBe(true);
    });

    it('validates scheduled notifications with future dates', () => {
      const futureDate = new Date(Date.now() + 86400000).toISOString();
      const scheduledPayload = {
        title: 'Upcoming Scheduled Sale',
        body: 'Get 50% discount on premium adblocker',
        notificationType: 'PROMOTION',
        destinationType: 'HOME',
        audienceType: 'TOPIC',
        audienceConfig: {
          topic: 'tx_promotions',
        },
        scheduledAt: futureDate,
      };

      const result = createNotificationSchema.safeParse(scheduledPayload);
      expect(result.success).toBe(true);
    });
  });

  describe('Notification API Guard Tests', () => {
    it('rejects unauthenticated requests with 401 Unauthorized', async () => {
      const { buildServer } = await import('../src/server.js');
      const app = await buildServer();

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/notifications',
      });

      expect(response.statusCode).toBe(401);
      const body = JSON.parse(response.body);
      expect(body.error.code).toBe('UNAUTHORIZED');

      await app.close();
    });

    it('rejects unauthenticated audience stats request with 401 Unauthorized', async () => {
      const { buildServer } = await import('../src/server.js');
      const app = await buildServer();

      const response = await app.inject({
        method: 'GET',
        url: '/api/v1/audiences/stats',
      });

      expect(response.statusCode).toBe(401);
      await app.close();
    });
  });
});

