import { getFirebaseMessaging } from './firebase';
import { prisma } from './prisma';

export const NOTIFICATION_CHANNELS: Record<string, string> = {
  GENERAL: 'tx_general',
  BROWSER_UPDATE: 'tx_updates',
  PROMOTION: 'tx_promotions',
  NEW_FEATURE: 'tx_updates',
  SECURITY: 'tx_security',
  ANNOUNCEMENT: 'tx_general',
  MAINTENANCE: 'tx_general',
};

export interface FcmPayloadInput {
  id: string;
  title: string;
  body: string;
  imageUrl?: string | null;
  notificationType?: string;
  destinationType?: string;
  destinationValue?: string | null;
}

export function formatFcmPayload(input: FcmPayloadInput) {
  const channelId = NOTIFICATION_CHANNELS[input.notificationType || 'GENERAL'] || 'tx_general';

  // Strict string-only data payload with BOTH snake_case and camelCase for 100% client compatibility
  const dataPayload: Record<string, string> = {
    notification_id: input.id,
    notificationId: input.id,
    id: input.id,
    notification_type: input.notificationType || 'GENERAL',
    notificationType: input.notificationType || 'GENERAL',
    type: input.notificationType || 'GENERAL',
    destination_type: input.destinationType || 'HOME',
    destinationType: input.destinationType || 'HOME',
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };

  if (input.destinationValue) {
    dataPayload.destination_value = input.destinationValue;
    dataPayload.destinationValue = input.destinationValue;
    dataPayload.url = input.destinationValue;
    dataPayload.link = input.destinationValue;
    dataPayload.target_url = input.destinationValue;
  }

  if (input.imageUrl) {
    dataPayload.image_url = input.imageUrl;
    dataPayload.imageUrl = input.imageUrl;
  }

  const androidPayload: Record<string, any> = {
    priority: 'high',
    notification: {
      channelId,
      clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      tag: input.id,
    },
  };

  if (input.imageUrl) {
    androidPayload.notification.imageUrl = input.imageUrl;
  }

  const notificationPayload: Record<string, any> = {
    title: input.title,
    body: input.body,
  };

  if (input.imageUrl) {
    notificationPayload.imageUrl = input.imageUrl;
  }

  return {
    notification: notificationPayload,
    data: dataPayload,
    android: androidPayload,
  };
}

export function chunkTokens(tokens: string[], size = 500): string[][] {
  const chunks: string[][] = [];
  for (let i = 0; i < tokens.length; i += size) {
    chunks.push(tokens.slice(i, i + size));
  }
  return chunks;
}

export async function sendFcmToTopic(topic: string, input: FcmPayloadInput) {
  const messaging = getFirebaseMessaging();
  const formatted = formatFcmPayload(input);

  const message: any = {
    topic,
    notification: formatted.notification,
    data: formatted.data,
    android: formatted.android,
  };

  return await messaging.send(message);
}

export async function sendFcmMulticastBatch(tokens: string[], input: FcmPayloadInput) {
  const messaging = getFirebaseMessaging();
  const formatted = formatFcmPayload(input);

  const message: any = {
    tokens,
    notification: formatted.notification,
    data: formatted.data,
    android: formatted.android,
  };

  const response = await messaging.sendEachForMulticast(message);

  const invalidTokens: string[] = [];
  const results = response.responses.map((res, idx) => {
    const token = tokens[idx];
    if (!res.success) {
      const errCode = res.error?.code || '';
      if (
        errCode === 'messaging/invalid-registration-token' ||
        errCode === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(token);
      }
      return { success: false, token, error: res.error?.message || errCode };
    }
    return { success: true, token, messageId: res.messageId };
  });

  // Automatically deactivate invalid / stale tokens in background
  if (invalidTokens.length > 0) {
    prisma.deviceInstallation
      .updateMany({
        where: { fcmToken: { in: invalidTokens } },
        data: { isActive: false },
      })
      .catch((err) => console.error('Error deactivating invalid FCM tokens:', err));
  }

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
    results,
    invalidTokens,
  };
}

export async function dispatchNotification(notificationId: string) {
  const notification = await prisma.notification.findUnique({
    where: { id: notificationId },
  });

  if (!notification) {
    throw new Error('Notification not found');
  }

  await prisma.notification.update({
    where: { id: notificationId },
    data: {
      status: 'SENDING',
      startedAt: new Date(),
    },
  });

  const notifInput: FcmPayloadInput = {
    id: notification.id,
    title: notification.title,
    body: notification.body,
    imageUrl: notification.imageUrl,
    notificationType: notification.notificationType,
    destinationType: notification.destinationType,
    destinationValue: notification.destinationValue,
  };

  let totalDelivered = 0;
  let totalFailed = 0;

  try {
    if (notification.audienceType === 'ALL_USERS' || notification.audienceType === 'TOPIC') {
      const topic =
        notification.audienceType === 'TOPIC'
          ? (notification.audienceConfig as any)?.topic || 'tx_all'
          : 'tx_all';

      // 1. Topic broadcast
      try {
        await sendFcmToTopic(topic, notifInput);
      } catch (err) {
        console.error('Topic broadcast error:', err);
      }

      // 2. Direct device delivery to ensure rapid delivery
      const devices = await prisma.deviceInstallation.findMany({
        where: { isActive: true },
        select: { id: true, installationId: true, fcmToken: true },
      });

      if (devices.length > 0) {
        const tokens = devices.map((d) => d.fcmToken);
        const chunks = chunkTokens(tokens, 500);

        for (const chunk of chunks) {
          try {
            const batchRes = await sendFcmMulticastBatch(chunk, notifInput);
            totalDelivered += batchRes.successCount;
            totalFailed += batchRes.failureCount;

            const successfulTokens = new Set(
              batchRes.results.filter((r) => r.success).map((r) => r.token)
            );
            const successfulDevices = devices.filter((d) => successfulTokens.has(d.fcmToken));

            if (successfulDevices.length > 0) {
              await prisma.notificationDelivery.createMany({
                data: successfulDevices.map((d) => ({
                  notificationId: notification.id,
                  installationId: d.installationId,
                  status: 'SENT',
                  sentAt: new Date(),
                })),
                skipDuplicates: true,
              }).catch(() => {});
            }
          } catch (err) {
            console.error('Batch delivery error:', err);
          }
        }
      }
    } else if (notification.audienceType === 'SEGMENT') {
      const config = (notification.audienceConfig as any) || {};
      const where: any = { isActive: true };

      if (config.activeWithinDays) {
        const threshold = new Date(Date.now() - config.activeWithinDays * 24 * 60 * 60 * 1000);
        where.lastSeenAt = { gte: threshold };
      }

      if (config.appVersion && config.appVersion !== 'ALL') {
        where.appVersion = config.appVersion;
      }

      const devices = await prisma.deviceInstallation.findMany({
        where,
        select: { id: true, installationId: true, fcmToken: true },
      });

      if (devices.length > 0) {
        const tokens = devices.map((d) => d.fcmToken);
        const chunks = chunkTokens(tokens, 500);

        for (const chunk of chunks) {
          try {
            const batchRes = await sendFcmMulticastBatch(chunk, notifInput);
            totalDelivered += batchRes.successCount;
            totalFailed += batchRes.failureCount;

            const successfulTokens = new Set(
              batchRes.results.filter((r) => r.success).map((r) => r.token)
            );
            const successfulDevices = devices.filter((d) => successfulTokens.has(d.fcmToken));

            if (successfulDevices.length > 0) {
              await prisma.notificationDelivery.createMany({
                data: successfulDevices.map((d) => ({
                  notificationId: notification.id,
                  installationId: d.installationId,
                  status: 'SENT',
                  sentAt: new Date(),
                })),
                skipDuplicates: true,
              }).catch(() => {});
            }
          } catch (err) {
            console.error('Segment send error:', err);
          }
        }
      }
    }

    const updated = await prisma.notification.update({
      where: { id: notificationId },
      data: {
        status: 'SENT',
        completedAt: new Date(),
      },
    });

    return {
      success: true,
      deliveredCount: totalDelivered,
      failedCount: totalFailed,
      notification: updated,
    };
  } catch (err: any) {
    console.error('Fatal dispatch error for notification', notificationId, err);
    await prisma.notification.update({
      where: { id: notificationId },
      data: { status: 'FAILED' },
    });
    throw err;
  }
}
