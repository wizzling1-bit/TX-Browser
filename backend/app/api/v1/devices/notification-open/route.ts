import { NextRequest, NextResponse } from 'next/server';
import { recordNotificationOpen } from '@/lib/device';
import { z } from 'zod';

const notificationOpenSchema = z.object({
  notificationId: z.string().uuid(),
  installationId: z.string().min(10).max(128),
  openedAt: z.string().datetime().optional(),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parseResult = notificationOpenSchema.safeParse(body);

    if (!parseResult.success) {
      return NextResponse.json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid notification open payload',
          details: parseResult.error.format(),
        },
      }, { status: 400 });
    }

    const { notificationId, installationId, openedAt } = parseResult.data;
    await recordNotificationOpen({
      notificationId,
      installationId,
      openedAt,
    });
    return NextResponse.json({ success: true });
  } catch (err: any) {
    console.error('Failed to record notification open event:', err);
    return NextResponse.json({
      success: false,
      error: {
        code: 'TRACKING_FAILED',
        message: 'Could not record notification open',
      },
    }, { status: 500 });
  }
}
