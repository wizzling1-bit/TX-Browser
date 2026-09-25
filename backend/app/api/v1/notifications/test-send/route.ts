import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { sendFcmMulticastBatch } from '@/lib/fcm';
import { z } from 'zod';

const testSendSchema = z.object({
  targetFcmToken: z.string().min(1, 'Target FCM Token is required'),
  title: z.string().min(1).default('TX Browser Test Ping'),
  body: z.string().min(1).default('This is a test notification dispatched from the TX Push Console.'),
  imageUrl: z.string().url().optional().nullable(),
  notificationType: z.string().optional().default('GENERAL'),
  destinationType: z.string().optional().default('HOME'),
  destinationValue: z.string().optional().nullable(),
});

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const parsed = testSendSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Invalid input', details: parsed.error.format() }, { status: 400 });
    }

    const { targetFcmToken, title, body: msgBody, imageUrl, notificationType, destinationType, destinationValue } = parsed.data;

    const result = await sendFcmMulticastBatch([targetFcmToken], {
      id: `test-${Date.now()}`,
      title,
      body: msgBody,
      imageUrl: imageUrl || null,
      notificationType,
      destinationType,
      destinationValue: destinationValue || null,
    });

    const isSuccess = result.successCount > 0;
    const failureDetail = result.results[0]?.error;

    return NextResponse.json({
      success: isSuccess,
      deliveredToToken: targetFcmToken.length > 20 ? `${targetFcmToken.substring(0, 16)}...` : targetFcmToken,
      result: result.results[0],
      error: isSuccess ? undefined : failureDetail || 'FCM rejected delivery to this token',
    });
  } catch (err: any) {
    console.error('Test send error:', err);
    return NextResponse.json({ success: false, error: err?.message || 'Failed to dispatch test notification' }, { status: 500 });
  }
}
