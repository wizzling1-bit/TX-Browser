import { prisma } from './prisma';

export interface RegisterDeviceInput {
  installationId: string;
  fcmToken: string;
  platform?: string;
  appVersion: string;
  buildNumber: number;
  androidVersion: string;
  deviceModel: string;
  notificationPermission: 'granted' | 'denied' | 'unknown' | string;
}

export interface HeartbeatInput {
  installationId: string;
  appVersion?: string;
  notificationPermission?: 'granted' | 'denied' | 'unknown' | string;
}

export interface NotificationOpenInput {
  notificationId: string;
  installationId: string;
  openedAt?: string;
}

export async function upsertInstallation(input: RegisterDeviceInput) {
  const now = new Date();

  const installation = await prisma.deviceInstallation.upsert({
    where: { installationId: input.installationId },
    create: {
      installationId: input.installationId,
      fcmToken: input.fcmToken,
      platform: input.platform || 'android',
      appVersion: input.appVersion,
      buildNumber: Number(input.buildNumber) || 1,
      androidVersion: input.androidVersion,
      deviceModel: input.deviceModel,
      notificationPermission: input.notificationPermission || 'unknown',
      isActive: true,
      lastSeenAt: now,
    },
    update: {
      fcmToken: input.fcmToken,
      appVersion: input.appVersion,
      buildNumber: Number(input.buildNumber) || 1,
      androidVersion: input.androidVersion,
      deviceModel: input.deviceModel,
      notificationPermission: input.notificationPermission || 'unknown',
      isActive: true,
      lastSeenAt: now,
    },
  });

  // Ensure default topics exist
  const defaultTopics = ['tx_all', 'tx_general', 'tx_promotions', 'tx_updates', 'tx_security'];
  for (const topic of defaultTopics) {
    await prisma.deviceTopic.upsert({
      where: {
        installationId_topic: {
          installationId: input.installationId,
          topic,
        },
      },
      create: {
        installationId: input.installationId,
        topic,
      },
      update: {},
    }).catch(() => {});
  }

  return installation;
}

export async function recordHeartbeat(input: HeartbeatInput) {
  const updateData: any = {
    lastSeenAt: new Date(),
    isActive: true,
  };

  if (input.appVersion) updateData.appVersion = input.appVersion;
  if (input.notificationPermission) {
    updateData.notificationPermission = input.notificationPermission;
  }

  return prisma.deviceInstallation.update({
    where: { installationId: input.installationId },
    data: updateData,
  });
}

export async function recordNotificationOpen(input: NotificationOpenInput) {
  const openedAt = input.openedAt ? new Date(input.openedAt) : new Date();

  const existing = await prisma.notificationDelivery.findFirst({
    where: {
      notificationId: input.notificationId,
      installationId: input.installationId,
    },
  });

  if (existing) {
    return prisma.notificationDelivery.update({
      where: { id: existing.id },
      data: {
        status: 'OPENED',
        openedAt,
      },
    });
  }

  return prisma.notificationDelivery.create({
    data: {
      notificationId: input.notificationId,
      installationId: input.installationId,
      status: 'OPENED',
      openedAt,
    },
  });
}
