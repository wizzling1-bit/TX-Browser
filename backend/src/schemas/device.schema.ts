import { z } from 'zod';

export const registerDeviceSchema = z.object({
  installationId: z.string().uuid('Invalid installation ID format'),
  fcmToken: z.string().min(10, 'FCM token must be at least 10 characters long').max(1024),
  appVersion: z.string().min(1).max(32),
  buildNumber: z.coerce.number().int().positive(),
  androidVersion: z.string().min(1).max(64),
  deviceModel: z.string().min(1).max(128),
  notificationPermission: z.enum(['granted', 'denied', 'unknown']).default('unknown'),
});

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;

export const heartbeatSchema = z.object({
  installationId: z.string().uuid('Invalid installation ID format'),
  appVersion: z.string().min(1).max(32).optional(),
  notificationPermission: z.enum(['granted', 'denied', 'unknown']).optional(),
});

export type HeartbeatInput = z.infer<typeof heartbeatSchema>;

export const notificationOpenSchema = z.object({
  notificationId: z.string().min(1),
  installationId: z.string().uuid('Invalid installation ID format'),
  openedAt: z.string().datetime().optional(),
});

export type NotificationOpenInput = z.infer<typeof notificationOpenSchema>;
