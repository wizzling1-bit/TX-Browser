import admin from 'firebase-admin';
import { PrismaClient } from '@prisma/client';
import { env } from '../config/env.js';
import prisma from '../db/prisma.js';

export interface FcmNotificationInput {
  id: string;
  title: string;
  body: string;
  imageUrl?: string | null;
  notificationType?: string;
  destinationType?: string;
  destinationValue?: string | null;
}

export interface MulticastBatchResult {
  successCount: number;
  failureCount: number;
  invalidTokens: string[];
  results: Array<{
    token: string;
    messageId?: string;
    error?: string;
    isInvalidToken: boolean;
  }>;
}

// Maps notification types to Android Notification Channel IDs defined in AndroidManifest.xml and Flutter NotificationService
export const NOTIFICATION_CHANNELS: Record<string, string> = {
  GENERAL: 'tx_general',
  BROWSER_UPDATE: 'tx_updates',
  PROMOTION: 'tx_promotions',
  NEW_FEATURE: 'tx_updates',
  SECURITY: 'tx_security',
  ANNOUNCEMENT: 'tx_general',
  MAINTENANCE: 'tx_general',
};

const INVALID_TOKEN_ERROR_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/mismatched-credential',
]);

export class FcmService {
  private messaging: any;
  private db: PrismaClient;

  constructor(messagingInstance?: any, prismaInstance?: PrismaClient) {
    this.db = prismaInstance || prisma;

    if (messagingInstance) {
      this.messaging = messagingInstance;
    } else {
      this.initFirebase();
    }
  }

  private initFirebase() {
    if (!admin.apps.length) {
      if (env.FIREBASE_PRIVATE_KEY && env.FIREBASE_CLIENT_EMAIL) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId: env.FIREBASE_PROJECT_ID,
            clientEmail: env.FIREBASE_CLIENT_EMAIL,
            privateKey: env.FIREBASE_PRIVATE_KEY,
          }),
        });
      } else {
        // Fallback for local testing/dev when credentials are pending
        admin.initializeApp({
          projectId: env.FIREBASE_PROJECT_ID,
        });
      }
    }
    this.messaging = admin.messaging();
  }

  /**
   * Helper to partition an array of tokens into chunks of specified size (FCM multicast max is 500).
   */
  chunkTokens(tokens: string[], size = 500): string[][] {
    const chunks: string[][] = [];
    for (let i = 0; i < tokens.length; i += size) {
      chunks.push(tokens.slice(i, i + size));
    }
    return chunks;
  }

  /**
   * Constructs the structured FCM payload following production requirements:
   * - notification: display title, body, imageUrl
   * - data: strict string-only key-value pairs for reliable background interception
   * - android: high priority, specific channel ID matching notification type
   */
  private formatPayload(notification: FcmNotificationInput) {
    const channelId = NOTIFICATION_CHANNELS[notification.notificationType || 'GENERAL'] || 'tx_general';

    const dataPayload: Record<string, string> = {
      notification_id: notification.id,
      notification_type: notification.notificationType || 'GENERAL',
      destination_type: notification.destinationType || 'HOME',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    };

    if (notification.destinationValue) {
      dataPayload.destination_value = notification.destinationValue;
    }

    if (notification.imageUrl) {
      dataPayload.image_url = notification.imageUrl;
    }

    const androidPayload: Record<string, any> = {
      priority: 'high',
      notification: {
        channelId,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        icon: 'ic_stat_tx_notify',
      },
    };

    if (notification.imageUrl) {
      androidPayload.notification.imageUrl = notification.imageUrl;
    }

    const notificationPayload: Record<string, any> = {
      title: notification.title,
      body: notification.body,
    };

    if (notification.imageUrl) {
      notificationPayload.imageUrl = notification.imageUrl;
    }

    return {
      notification: notificationPayload,
      data: dataPayload,
      android: androidPayload,
    };
  }

  /**
   * Broadcasts to an FCM Topic (e.g. 'tx_all', 'tx_promotions', 'tx_updates').
   * Used for zero-latency mass fan-out.
   */
  async sendToTopic(topic: string, notification: FcmNotificationInput): Promise<{ messageId: string }> {
    const formatted = this.formatPayload(notification);

    const message: admin.messaging.Message = {
      topic,
      notification: formatted.notification,
      data: formatted.data,
      android: formatted.android as admin.messaging.AndroidConfig,
    };

    const messageId = await this.messaging.send(message);
    return { messageId };
  }

  /**
   * Sends multicast message to a batch of up to 500 tokens using sendEachForMulticast.
   * Identifies any expired or unregistered tokens for automatic cleanup.
   */
  async sendMulticastBatch(
    tokens: string[],
    notification: FcmNotificationInput
  ): Promise<MulticastBatchResult> {
    if (!tokens.length) {
      return { successCount: 0, failureCount: 0, invalidTokens: [], results: [] };
    }

    const formatted = this.formatPayload(notification);

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: formatted.notification,
      data: formatted.data,
      android: formatted.android as admin.messaging.AndroidConfig,
    };

    const response = await this.messaging.sendEachForMulticast(message);

    const invalidTokens: string[] = [];
    const results: MulticastBatchResult['results'] = [];

    response.responses.forEach((resp: any, index: number) => {
      const token = tokens[index];
      if (resp.success) {
        results.push({
          token,
          messageId: resp.messageId,
          isInvalidToken: false,
        });
      } else {
        const errorCode = resp.error?.code || 'unknown';
        const isInvalid = INVALID_TOKEN_ERROR_CODES.has(errorCode);

        if (isInvalid) {
          invalidTokens.push(token);
        }

        results.push({
          token,
          error: resp.error?.message || errorCode,
          isInvalidToken: isInvalid,
        });
      }
    });

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
      invalidTokens,
      results,
    };
  }

  /**
   * Deactivates devices whose FCM tokens were rejected as unregistered by FCM.
   */
  async deactivateInvalidTokens(invalidTokens: string[]): Promise<number> {
    if (!invalidTokens.length) return 0;

    const result = await this.db.deviceInstallation.updateMany({
      where: {
        fcmToken: {
          in: invalidTokens,
        },
      },
      data: {
        isActive: false,
      },
    });

    return result.count;
  }
}

export const fcmService = new FcmService();
