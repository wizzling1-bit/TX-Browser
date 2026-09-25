import { z } from 'zod';

const httpsUrl = z
  .string()
  .url('Must be a valid URL')
  .refine((url) => url.startsWith('https://'), {
    message: 'URL must start with https:// for strict security',
  });

export const notificationTypes = [
  'GENERAL',
  'BROWSER_UPDATE',
  'PROMOTION',
  'NEW_FEATURE',
  'SECURITY',
  'ANNOUNCEMENT',
  'MAINTENANCE',
] as const;

export const destinationTypes = [
  'HOME',
  'WEB_URL',
  'PLAY_STORE',
  'INTERNAL_SCREEN',
  'NO_ACTION',
] as const;

export const audienceTypes = ['ALL_USERS', 'TOPIC', 'SEGMENT'] as const;

export const audienceConfigSchema = z
  .object({
    topic: z.string().optional(),
    appVersion: z.string().optional(),
    minAndroidVersion: z.string().optional(),
    activeWithinDays: z.number().int().positive().optional(),
  })
  .optional()
  .nullable();

export const notificationBaseSchema = z.object({
  title: z.string().trim().min(1, 'Title cannot be empty').max(100, 'Title cannot exceed 100 characters'),
  body: z.string().trim().min(1, 'Body cannot be empty').max(500, 'Body cannot exceed 500 characters'),
  imageUrl: httpsUrl.optional().nullable(),
  notificationType: z.enum(notificationTypes).default('GENERAL'),
  destinationType: z.enum(destinationTypes).default('HOME'),
  destinationValue: z.string().trim().optional().nullable(),
  audienceType: z.enum(audienceTypes).default('ALL_USERS'),
  audienceConfig: audienceConfigSchema,
  scheduledAt: z.string().datetime().optional().nullable(),
});

function refineWebUrl(data: any, ctx: z.RefinementCtx) {
  if (data.destinationType === 'WEB_URL') {
    if (!data.destinationValue) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Destination URL is required when destination type is WEB_URL',
        path: ['destinationValue'],
      });
    } else if (!data.destinationValue.startsWith('https://')) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Destination URL must use secure https:// protocol',
        path: ['destinationValue'],
      });
    }
  }
}

export const createNotificationSchema = notificationBaseSchema.superRefine(refineWebUrl);
export const updateNotificationSchema = notificationBaseSchema.partial().superRefine(refineWebUrl);

export const queryNotificationsSchema = z.object({
  status: z.string().optional(),
  type: z.string().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export type CreateNotificationInput = z.infer<typeof createNotificationSchema>;
export type UpdateNotificationInput = z.infer<typeof updateNotificationSchema>;
export type QueryNotificationsInput = z.infer<typeof queryNotificationsSchema>;
