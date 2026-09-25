import { describe, it, expect, vi, beforeEach } from 'vitest';
import { FcmService } from '../src/services/fcm.service.js';
import { QueueService } from '../src/services/queue.service.js';
import { SchedulerService } from '../src/services/scheduler.service.js';

describe('FCM Delivery, Queue & Scheduler Unit Tests', () => {
  let mockFirebaseMessaging: any;
  let mockPrisma: any;
  let fcmService: FcmService;
  let queueService: QueueService;
  let schedulerService: SchedulerService;

  beforeEach(() => {
    mockFirebaseMessaging = {
      send: vi.fn(),
      sendEachForMulticast: vi.fn(),
    };

    mockPrisma = {
      deviceInstallation: {
        findMany: vi.fn(),
        updateMany: vi.fn(),
      },
      notification: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        update: vi.fn(),
      },
      notificationJob: {
        create: vi.fn(),
        createMany: vi.fn(),
        findFirst: vi.fn(),
        findMany: vi.fn(),
        update: vi.fn(),
        count: vi.fn(),
      },
      notificationDelivery: {
        create: vi.fn(),
        createMany: vi.fn(),
      },
      $queryRaw: vi.fn(),
      $transaction: vi.fn((callback: any) => callback(mockPrisma)),
    };

    fcmService = new FcmService(mockFirebaseMessaging, mockPrisma);
    queueService = new QueueService(mockPrisma, fcmService);
    schedulerService = new SchedulerService(mockPrisma, queueService);
  });

  describe('FcmService', () => {
    it('correctly chunks tokens into batches of maximum 500', () => {
      const tokens = Array.from({ length: 1250 }, (_, i) => `token_${i}`);
      const chunks = fcmService.chunkTokens(tokens, 500);

      expect(chunks.length).toBe(3);
      expect(chunks[0].length).toBe(500);
      expect(chunks[1].length).toBe(500);
      expect(chunks[2].length).toBe(250);
    });

    it('formats topic notification message with string data payload and correct Android channel', async () => {
      mockFirebaseMessaging.send.mockResolvedValue('projects/tx-browser/messages/topic-msg-123');

      const result = await fcmService.sendToTopic('tx_promotions', {
        id: 'notif-1',
        title: 'Spring Special Offer',
        body: 'Check out new extensions!',
        imageUrl: 'https://example.com/promo.png',
        notificationType: 'PROMOTION',
        destinationType: 'WEB_URL',
        destinationValue: 'https://example.com/promo',
      });

      expect(mockFirebaseMessaging.send).toHaveBeenCalledTimes(1);
      const sentPayload = mockFirebaseMessaging.send.mock.calls[0][0];

      expect(sentPayload.topic).toBe('tx_promotions');
      expect(sentPayload.notification).toEqual({
        title: 'Spring Special Offer',
        body: 'Check out new extensions!',
        imageUrl: 'https://example.com/promo.png',
      });
      expect(sentPayload.data).toEqual({
        notification_id: 'notif-1',
        notification_type: 'PROMOTION',
        destination_type: 'WEB_URL',
        destination_value: 'https://example.com/promo',
        image_url: 'https://example.com/promo.png',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      });
      expect(sentPayload.android.notification.channelId).toBe('tx_promotions');
      expect(result.messageId).toBe('projects/tx-browser/messages/topic-msg-123');
    });

    it('sends multicast batch and detects invalid/unregistered tokens for deactivation', async () => {
      mockFirebaseMessaging.sendEachForMulticast.mockResolvedValue({
        successCount: 2,
        failureCount: 1,
        responses: [
          { success: true, messageId: 'msg-1' },
          {
            success: false,
            error: {
              code: 'messaging/registration-token-not-registered',
              message: 'Token is no longer valid',
            },
          },
          { success: true, messageId: 'msg-3' },
        ],
      });

      mockPrisma.deviceInstallation.updateMany.mockResolvedValue({ count: 1 });

      const tokens = ['token-1', 'token-2', 'token-3'];
      const result = await fcmService.sendMulticastBatch(tokens, {
        id: 'notif-2',
        title: 'Security Update',
        body: 'Patch available',
        notificationType: 'SECURITY',
        destinationType: 'HOME',
      });

      expect(result.successCount).toBe(2);
      expect(result.failureCount).toBe(1);
      expect(result.invalidTokens).toEqual(['token-2']);

      const deactivatedCount = await fcmService.deactivateInvalidTokens(result.invalidTokens);
      expect(mockPrisma.deviceInstallation.updateMany).toHaveBeenCalledWith({
        where: { fcmToken: { in: ['token-2'] } },
        data: { isActive: false },
      });
      expect(deactivatedCount).toBe(1);
    });
  });

  describe('QueueService', () => {
    it('enqueues a topic send job for ALL_USERS audience and sets notification status to QUEUED', async () => {
      mockPrisma.notification.findUnique.mockResolvedValue({
        id: 'notif-100',
        title: 'Global Announcement',
        body: 'Welcome to TX Browser',
        audienceType: 'ALL_USERS',
        notificationType: 'GENERAL',
        destinationType: 'HOME',
        status: 'DRAFT',
      });

      mockPrisma.notificationJob.create.mockResolvedValue({ id: 'job-1' });
      mockPrisma.notification.update.mockResolvedValue({ id: 'notif-100', status: 'QUEUED' });

      await queueService.enqueueNotification('notif-100');

      expect(mockPrisma.notificationJob.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          notificationId: 'notif-100',
          jobType: 'TOPIC_SEND',
          payload: expect.objectContaining({
            topic: 'tx_all',
          }),
          status: 'PENDING',
        }),
      });

      expect(mockPrisma.notification.update).toHaveBeenCalledWith({
        where: { id: 'notif-100' },
        data: expect.objectContaining({ status: 'QUEUED' }),
      });
    });

    it('enqueues chunked multicast jobs for SEGMENT audience', async () => {
      mockPrisma.notification.findUnique.mockResolvedValue({
        id: 'notif-200',
        title: 'Segment Target',
        body: 'For Android 14 only',
        audienceType: 'SEGMENT',
        audienceConfig: { minAndroidVersion: '14' },
        notificationType: 'NEW_FEATURE',
        destinationType: 'HOME',
        status: 'DRAFT',
      });

      // 600 devices => 2 batches (500 + 100)
      const mockDevices = Array.from({ length: 600 }, (_, i) => ({
        installationId: `inst-${i}`,
        fcmToken: `token-${i}`,
      }));

      mockPrisma.deviceInstallation.findMany.mockResolvedValue(mockDevices);
      mockPrisma.notificationJob.createMany.mockResolvedValue({ count: 2 });
      mockPrisma.notification.update.mockResolvedValue({ id: 'notif-200', status: 'QUEUED' });

      await queueService.enqueueNotification('notif-200');

      expect(mockPrisma.deviceInstallation.findMany).toHaveBeenCalled();
      expect(mockPrisma.notificationJob.createMany).toHaveBeenCalledWith({
        data: expect.arrayContaining([
          expect.objectContaining({
            notificationId: 'notif-200',
            jobType: 'MULTICAST_BATCH',
          }),
        ]),
      });
      const createdJobs = mockPrisma.notificationJob.createMany.mock.calls[0][0].data;
      expect(createdJobs.length).toBe(2);
      expect((createdJobs[0].payload as any).tokens.length).toBe(500);
      expect((createdJobs[1].payload as any).tokens.length).toBe(100);
    });

    it('processes a pending TOPIC job and marks it completed', async () => {
      const mockJob = {
        id: 'job-99',
        notificationId: 'notif-100',
        jobType: 'TOPIC_SEND',
        payload: {
          topic: 'tx_all',
          notification: {
            id: 'notif-100',
            title: 'Hello',
            body: 'World',
            notificationType: 'GENERAL',
            destinationType: 'HOME',
          },
        },
        attempts: 0,
        maxAttempts: 3,
        status: 'PENDING',
      };

      mockPrisma.notificationJob.findFirst.mockResolvedValue(mockJob);
      mockPrisma.notificationJob.update.mockResolvedValue({ ...mockJob, status: 'COMPLETED' });
      mockFirebaseMessaging.send.mockResolvedValue('msg-id-99');
      mockPrisma.notificationJob.count.mockResolvedValue(0); // 0 remaining pending jobs
      mockPrisma.notification.update.mockResolvedValue({ id: 'notif-100', status: 'SENT' });

      const processed = await queueService.processNextJob('test-worker');
      expect(processed).toBe(true);

      expect(mockFirebaseMessaging.send).toHaveBeenCalled();
      expect(mockPrisma.notificationDelivery.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          notificationId: 'notif-100',
          providerMessageId: 'msg-id-99',
          status: 'SENT',
        }),
      });
      expect(mockPrisma.notificationJob.update).toHaveBeenCalledWith({
        where: { id: 'job-99' },
        data: expect.objectContaining({ status: 'COMPLETED' }),
      });
      expect(mockPrisma.notification.update).toHaveBeenCalledWith({
        where: { id: 'notif-100' },
        data: expect.objectContaining({ status: 'SENT' }),
      });
    });
  });

  describe('SchedulerService', () => {
    it('polls due scheduled notifications and enqueues them', async () => {
      const dueNotifications = [
        { id: 'notif-sched-1', status: 'SCHEDULED', scheduledAt: new Date(Date.now() - 5000) },
        { id: 'notif-sched-2', status: 'SCHEDULED', scheduledAt: new Date(Date.now() - 1000) },
      ];

      mockPrisma.notification.findMany.mockResolvedValue(dueNotifications);
      vi.spyOn(queueService, 'enqueueNotification').mockResolvedValue(undefined as any);

      const count = await schedulerService.pollScheduledNotifications();
      expect(count).toBe(2);
      expect(queueService.enqueueNotification).toHaveBeenCalledWith('notif-sched-1');
      expect(queueService.enqueueNotification).toHaveBeenCalledWith('notif-sched-2');
    });
  });
});
