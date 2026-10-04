import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { z } from 'zod';

export const dynamic = 'force-dynamic';

const feedbackSchema = z.object({
  category: z.enum(['BROKEN_WEBSITE', 'AD_BLOCKER_ISSUE', 'CRASH_BUG', 'PERFORMANCE', 'FEATURE_REQUEST', 'OTHER']).default('BROKEN_WEBSITE'),
  targetUrl: z.string().optional().nullable(),
  description: z.string().min(2, 'Description is required'),
  deviceModel: z.string().optional().nullable(),
  androidVersion: z.string().optional().nullable(),
  appVersion: z.string().optional().nullable(),
  shieldEnabled: z.boolean().default(true),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = feedbackSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Invalid input', details: parsed.error.format() }, { status: 400 });
    }

    const { category, targetUrl, description, deviceModel, androidVersion, appVersion, shieldEnabled } = parsed.data;

    const feedback = await prisma.userFeedback.create({
      data: {
        category,
        targetUrl: targetUrl || null,
        description,
        deviceModel: deviceModel || null,
        androidVersion: androidVersion || null,
        appVersion: appVersion || null,
        shieldEnabled,
        status: 'NEW',
      },
    });

    return NextResponse.json(
      {
        success: true,
        message: 'Feedback submitted successfully. Thank you for making TX Browser better!',
        feedbackId: feedback.id,
      },
      { status: 201 }
    );
  } catch (error: any) {
    console.error('[Feedback API] Error:', error);
    return NextResponse.json(
      {
        error: error?.message || 'Failed to submit feedback',
      },
      { status: 500 }
    );
  }
}
