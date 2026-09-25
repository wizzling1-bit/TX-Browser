import { NextRequest, NextResponse } from 'next/server';
import { upsertInstallation, RegisterDeviceInput } from '@/lib/device';
import { z } from 'zod';

const registerDeviceSchema = z.object({
  installationId: z.string().min(10).max(128),
  fcmToken: z.string().min(20).max(4096),
  platform: z.literal('android').default('android'),
  appVersion: z.string().min(1).max(32),
  buildNumber: z.number().int().positive(),
  androidVersion: z.string().min(1).max(32),
  deviceModel: z.string().min(1).max(128),
  notificationPermission: z.enum(['granted', 'denied', 'unknown']).default('unknown'),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parseResult = registerDeviceSchema.safeParse(body);

    if (!parseResult.success) {
      return NextResponse.json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid device registration payload',
          details: parseResult.error.format(),
        },
      }, { status: 400 });
    }

    const payload: RegisterDeviceInput = {
      installationId: parseResult.data.installationId,
      fcmToken: parseResult.data.fcmToken,
      platform: parseResult.data.platform,
      appVersion: parseResult.data.appVersion,
      buildNumber: parseResult.data.buildNumber,
      androidVersion: parseResult.data.androidVersion,
      deviceModel: parseResult.data.deviceModel,
      notificationPermission: parseResult.data.notificationPermission,
    };

    const installation = await upsertInstallation(payload);
    return NextResponse.json({
      success: true,
      data: {
        installationId: installation.installationId,
        isActive: installation.isActive,
        updatedAt: installation.updatedAt,
      },
    });
  } catch (err: any) {
    console.error('Failed to register device:', err);
    return NextResponse.json({
      success: false,
      error: {
        code: 'REGISTRATION_FAILED',
        message: 'Could not register device installation: ' + err?.message,
      },
    }, { status: 500 });
  }
}
