import { NextRequest, NextResponse } from 'next/server';
import { recordHeartbeat } from '@/lib/device';
import { z } from 'zod';

const heartbeatSchema = z.object({
  installationId: z.string().min(10).max(128),
  appVersion: z.string().min(1).max(32).optional(),
  notificationPermission: z.enum(['granted', 'denied', 'unknown']).optional(),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parseResult = heartbeatSchema.safeParse(body);

    if (!parseResult.success) {
      return NextResponse.json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid heartbeat payload',
          details: parseResult.error.format(),
        },
      }, { status: 400 });
    }

    const { installationId, appVersion, notificationPermission } = parseResult.data;
    await recordHeartbeat({
      installationId,
      appVersion,
      notificationPermission,
    });
    return NextResponse.json({ success: true });
  } catch (err: any) {
    console.warn('Device heartbeat warning:', err);
    // Return 200 with success: false so client does not spin or retry aggressively
    return NextResponse.json({ success: false });
  }
}
