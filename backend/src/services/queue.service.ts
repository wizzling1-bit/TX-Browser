import { PrismaClient } from '@prisma/client';
import prisma from '../db/prisma.js';
import { FcmService, fcmService as defaultFcmService } from './fcm.service.js';

export class QueueService {
  private db: PrismaClient;
  private fcm: FcmService;
  private workerTimer: NodeJS.Timeout | null = null;
  private isProcessing = false;

  constructor(prismaInstance?: PrismaClient, fcmInstance?: FcmService) {
    this.db = prismaInstance || prisma;
    this.fcm = fcmInstance || defaultFcmService;
  }

  /**
   * Enqueues a notification for delivery by creating one or more delivery jobs.
   * - Broad audience (ALL_USERS or TOPIC) -> Single TOPIC_SEND job.
   * - Segmented audience -> Queries matching devices, chunks into 500-token batches, creates MULTICAST_BATCH jobs.
   */
  async enqueueNotification(notificationId: string): Promise<void> {
    const notification = await this.db.notification.findUnique({
      where: { id: notificationId },
    });

    if (!notification) {
      throw new Error(`Notification with id ${notificationId} not found.`);
    }

    if (notification.status === 'CANCELLED') {
      return;
    }

    const notifInput = {
      id: notification.id,
      title: notification.title,
      body: notification.body,
      imageUrl: notification.imageUrl,
      notificationType: notification.notificationType,
      destinationType: notification.destinationType,
      destinationValue: notification.destinationValue,
    };

    if (notification.audienceType === 'ALL_USERS') {
      await this.db.notificationJob.create({
        data: {
          notificationId: notification.id,
          jobType: 'TOPIC_SEND',
          payload: {
            topic: 'tx_all',
            notification: notifInput,
          },
          status: 'PENDING',
        },
      });
    } else if (notification.audienceType === 'TOPIC') {
      const config = notification.audienceConfig as any;
      const topic = config?.topic || 'tx_all';

      await this.db.notificationJob.create({
        data: {
          notificationId: notification.id,
          jobType: 'TOPIC_SEND',
          payload: {
            topic,
            notification: notifInput,
          },
          status: 'PENDING',
        },
      });
    } else if (notification.audienceType === 'SEGMENT') {
      const config = (notification.audienceConfig as any) || {};

      const whereClause: any = {
        isActive: true,
        notificationPermission: 'granted',
      };

      if (config.appVersion) {
        whereClause.appVersion = config.appVersion;
      }

      if (config.activeWithinDays && typeof config.activeWithinDays === 'number') {
        const cutoff = new Date(Date.now() - config.activeWithinDays * 24 * 60 * 60 * 1000);
        whereClause.lastSeenAt = { gte: cutoff };
      }

      const devices = await this.db.deviceInstallation.findMany({
        where: whereClause,
        select: {
          installationId: true,
          fcmToken: true,
        },
      });

      const tokens = devices.map((d) => d.fcmToken);
      const installationMap = devices.reduce<Record<string, string>>((acc, d) => {
        acc[d.fcmToken] = d.installationId;
        return acc;
      }, {});

      const chunks = this.fcm.chunkTokens(tokens, 500);

      if (chunks.length === 0) {
        // No devices match segment - complete notification immediately
        await this.db.notification.update({
          where: { id: notification.id },
          data: {
            status: 'SENT',
            startedAt: new Date(),
            completedAt: new Date(),
          },
        });
        return;
      }

      const jobsData = chunks.map((chunk, idx) => ({
        notificationId: notification.id,
        jobType: 'MULTICAST_BATCH',
        payload: {
          tokens: chunk,
          installationMap,
          notification: notifInput,
          chunkIndex: idx,
          totalChunks: chunks.length,
        },
        status: 'PENDING' as const,
      }));

      await this.db.notificationJob.createMany({
        data: jobsData,
      });
    }

    await this.db.notification.update({
      where: { id: notification.id },
      data: {
        status: 'QUEUED',
        startedAt: new Date(),
      },
    });
  }

  /**
   * Acquires the next pending job using PostgreSQL row locking (FOR UPDATE SKIP LOCKED)
   * processes it via FCM, records delivery metrics, and handles state transitions.
   */
  async processNextJob(workerId = 'worker-1'): Promise<boolean> {
    let job: any = null;

    try {
      const lockedRows: any = await this.db.$queryRaw`
        SELECT id FROM notification_jobs
        WHERE status = 'PENDING'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE SKIP LOCKED
      `;

      if (Array.isArray(lockedRows) && lockedRows.length > 0) {
        job = await this.db.notificationJob.findFirst({
          where: { id: lockedRows[0].id },
        });
      } else {
        job = await this.db.notificationJob.findFirst({
          where: { status: 'PENDING' },
          orderBy: { createdAt: 'asc' },
        });
      }
    } catch {
      // Fallback for mocks / environments without FOR UPDATE SKIP LOCKED
      job = await this.db.notificationJob.findFirst({
        where: { status: 'PENDING' },
        orderBy: { createdAt: 'asc' },
      });
    }

    if (!job) {
      return false;
    }

    const currentAttempts = (job.attempts || 0) + 1;

    await this.db.notificationJob.update({
      where: { id: job.id },
      data: {
        status: 'PROCESSING',
        attempts: currentAttempts,
        lockedAt: new Date(),
        lockedBy: workerId,
      },
    });

    try {
      const payload = job.payload as any;

      if (job.jobType === 'TOPIC_SEND') {
        const result = await this.fcm.sendToTopic(payload.topic, payload.notification);

        await this.db.notificationDelivery.create({
          data: {
            notificationId: job.notificationId,
            providerMessageId: result.messageId,
            status: 'SENT',
            sentAt: new Date(),
          },
        });
      } else if (job.jobType === 'MULTICAST_BATCH') {
        const batchResult = await this.fcm.sendMulticastBatch(payload.tokens, payload.notification);

        if (batchResult.invalidTokens.length > 0) {
          await this.fcm.deactivateInvalidTokens(batchResult.invalidTokens);
        }

        if (batchResult.results.length > 0) {
          const deliveryRecords = batchResult.results.map((r) => ({
            notificationId: job.notificationId,
            installationId: payload.installationMap?.[r.token] || null,
            providerMessageId: r.messageId || null,
            status: r.messageId ? 'SENT' : 'FAILED',
            errorCode: r.isInvalidToken ? 'INVALID_TOKEN' : (r.error ? 'DELIVERY_ERROR' : null),
            errorMessage: r.error || null,
            sentAt: r.messageId ? new Date() : null,
          }));

          await this.db.notificationDelivery.createMany({
            data: deliveryRecords,
          });
        }
      }

      await this.db.notificationJob.update({
        where: { id: job.id },
        data: {
          status: 'COMPLETED',
        },
      });

      // Check if all jobs for this notification are finished
      const remainingJobs = await this.db.notificationJob.count({
        where: {
          notificationId: job.notificationId,
          status: { in: ['PENDING', 'PROCESSING'] },
        },
      });

      if (remainingJobs === 0) {
        await this.db.notification.update({
          where: { id: job.notificationId },
          data: {
            status: 'SENT',
            completedAt: new Date(),
          },
        });
      }

      return true;
    } catch (error: any) {
      const isExhausted = currentAttempts >= job.maxAttempts;

      await this.db.notificationJob.update({
        where: { id: job.id },
        data: {
          status: isExhausted ? 'FAILED' : 'PENDING',
          errorMessage: error?.message || 'Unknown processing error',
        },
      });

      if (isExhausted) {
        await this.db.notification.update({
          where: { id: job.notificationId },
          data: {
            status: 'FAILED',
            completedAt: new Date(),
          },
        });
      }

      return false;
    }
  }

  startWorker(intervalMs = 3000): void {
    if (this.workerTimer) return;

    this.workerTimer = setInterval(async () => {
      if (this.isProcessing) return;
      this.isProcessing = true;

      try {
        let hasMore = true;
        while (hasMore) {
          hasMore = await this.processNextJob();
        }
      } catch (err) {
        console.error('Error in QueueService worker cycle:', err);
      } finally {
        this.isProcessing = false;
      }
    }, intervalMs);
  }

  stopWorker(): void {
    if (this.workerTimer) {
      clearInterval(this.workerTimer);
      this.workerTimer = null;
    }
  }
}

export const queueService = new QueueService();
