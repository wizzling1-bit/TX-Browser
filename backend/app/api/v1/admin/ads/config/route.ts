import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

export const dynamic = 'force-dynamic';

const updateAdConfigSchema = z.object({
  admobAppId: z.string().min(5),
  bannerEnabled: z.boolean(),
  interstitialEnabled: z.boolean(),
  rewardedEnabled: z.boolean(),
  nativeEnabled: z.boolean(),
  appOpenEnabled: z.boolean(),
  bannerAdUnitId: z.string().min(5),
  interstitialAdUnitId: z.string().min(5),
  rewardedAdUnitId: z.string().min(5),
  appOpenAdUnitId: z.string().min(5),
  nativeAdUnitId: z.string().min(5),
  rewardedPerkMinutes: z.number().int().min(1).max(120),
  interstitialIntervalMinutes: z.number().int().min(1).max(60),
  interstitialPageThreshold: z.number().int().min(1).max(20),
  activePerkMultiplier: z.number().min(0.1).max(10.0),
  killSwitch: z.boolean(),
  mediationNetwork: z.string().default('ADMOB'),
});

const DEFAULT_CONFIG = {
  id: 'global',
  admobAppId: 'ca-app-pub-3435015056397165~5473577665',
  bannerEnabled: true,
  interstitialEnabled: true,
  rewardedEnabled: true,
  nativeEnabled: true,
  appOpenEnabled: true,
  bannerAdUnitId: 'ca-app-pub-3435015056397165/1621912239',
  interstitialAdUnitId: 'ca-app-pub-3435015056397165/8850550042',
  rewardedAdUnitId: 'ca-app-pub-3435015056397165/8658978359',
  appOpenAdUnitId: 'ca-app-pub-3435015056397165/3538513614',
  nativeAdUnitId: 'ca-app-pub-3435015056397165/5210687936',
  rewardedPerkMinutes: 10,
  interstitialIntervalMinutes: 5,
  interstitialPageThreshold: 4,
  activePerkMultiplier: 1.0,
  killSwitch: false,
  mediationNetwork: 'ADMOB',
};

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    let config = await prisma.adConfiguration.findUnique({
      where: { id: 'global' },
    });

    if (!config) {
      config = await prisma.adConfiguration.create({
        data: DEFAULT_CONFIG,
      });
    }

    return NextResponse.json({ success: true, config });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to retrieve ad configuration' }, { status: 500 });
  }
}

export async function PUT(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const parsed = updateAdConfigSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const updated = await prisma.adConfiguration.upsert({
      where: { id: 'global' },
      create: {
        id: 'global',
        ...parsed.data,
      },
      update: parsed.data,
    });

    // Create audit log
    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'UPDATE_AD_CONFIGURATION',
        resourceType: 'AdConfiguration',
        resourceId: 'global',
        metadata: parsed.data,
      },
    });

    return NextResponse.json({ success: true, config: updated });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to update ad configuration' }, { status: 500 });
  }
}
