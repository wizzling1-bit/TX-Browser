import { PrismaClient } from '@prisma/client';
import prisma from '../db/prisma.js';
import { QueueService, queueService as defaultQueueService } from './queue.service.js';

export class SchedulerService {
  private db: PrismaClient;
  private queue: QueueService;
  private schedulerTimer: NodeJS.Timeout | null = null;
  private isPolling = false;

  constructor(prismaInstance?: PrismaClient, queueInstance?: QueueService) {
    this.db = prismaInstance || prisma;
    this.queue = queueInstance || defaultQueueService;
  }

  /**
   * Scans for notifications scheduled at or before the current time and enqueues them for delivery.
   */
  async pollScheduledNotifications(): Promise<number> {
    const dueNotifications = await this.db.notification.findMany({
      where: {
        status: 'SCHEDULED',
        scheduledAt: {
          lte: new Date(),
        },
      },
      select: {
        id: true,
      },
      orderBy: {
        scheduledAt: 'asc',
      },
    });

    if (!dueNotifications.length) {
      return 0;
    }

    for (const notif of dueNotifications) {
      try {
        await this.queue.enqueueNotification(notif.id);
      } catch (err) {
        console.error(`Failed to enqueue scheduled notification ${notif.id}:`, err);
      }
    }

    return dueNotifications.length;
  }

  startScheduler(intervalMs = 15000): void {
    if (this.schedulerTimer) return;

    this.schedulerTimer = setInterval(async () => {
      if (this.isPolling) return;
      this.isPolling = true;

      try {
        await this.pollScheduledNotifications();
      } catch (err) {
        console.error('Error during SchedulerService poll:', err);
      } finally {
        this.isPolling = false;
      }
    }, intervalMs);
  }

  stopScheduler(): void {
    if (this.schedulerTimer) {
      clearInterval(this.schedulerTimer);
      this.schedulerTimer = null;
    }
  }
}

export const schedulerService = new SchedulerService();
