import { PrismaClient } from '@prisma/client';
import { RegisterDeviceInput, HeartbeatInput, NotificationOpenInput } from '../schemas/device.schema.js';
import { prisma as defaultPrisma } from '../db/prisma.js';

export class DeviceService {
  constructor(private db: PrismaClient = defaultPrisma) {}

  /**
   * Upserts the installation metadata and FCM token.
   * If token changed, marks isActive = true and updates lastSeenAt.
   */
  async upsertInstallation(input: RegisterDeviceInput) {
    const now = new Date();

    return this.db.deviceInstallation.upsert({
      where: { installationId: input.installationId },
      create: {
        installationId: input.installationId,
        fcmToken: input.fcmToken,
        platform: 'android',
        appVersion: input.appVersion,
        buildNumber: input.buildNumber,
        androidVersion: input.androidVersion,
        deviceModel: input.deviceModel,
        notificationPermission: input.notificationPermission,
        isActive: true,
        lastSeenAt: now,
      },
      update: {
        fcmToken: input.fcmToken,
        appVersion: input.appVersion,
        buildNumber: input.buildNumber,
        androidVersion: input.androidVersion,
        deviceModel: input.deviceModel,
        notificationPermission: input.notificationPermission,
        isActive: true,
        lastSeenAt: now,
      },
    });
  }

  /**
   * Lightweight heartbeat to record device activity and updated permission status.
   */
  async recordHeartbeat(input: HeartbeatInput) {
    const updateData: {
      lastSeenAt: Date;
      isActive: boolean;
      appVersion?: string;
      notificationPermission?: string;
    } = {
      lastSeenAt: new Date(),
      isActive: true,
    };

    if (input.appVersion) updateData.appVersion = input.appVersion;
    if (input.notificationPermission) {
      updateData.notificationPermission = input.notificationPermission;
    }

    return this.db.deviceInstallation.update({
      where: { installationId: input.installationId },
      data: updateData,
    });
  }

  /**
   * Records a notification opened event for delivery tracking and analytics.
   */
  async recordNotificationOpen(input: NotificationOpenInput) {
    const openedAt = input.openedAt ? new Date(input.openedAt) : new Date();

    const existing = await this.db.notificationDelivery.findFirst({
      where: {
        notificationId: input.notificationId,
        installationId: input.installationId,
      },
    });

    if (existing) {
      return this.db.notificationDelivery.update({
        where: { id: existing.id },
        data: {
          status: 'OPENED',
          openedAt,
        },
      });
    }

    return this.db.notificationDelivery.create({
      data: {
        notificationId: input.notificationId,
        installationId: input.installationId,
        status: 'OPENED',
        openedAt,
      },
    });
  }
}

export const deviceService = new DeviceService();
