import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

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
  try {
    const config = await prisma.adConfiguration.findUnique({
      where: { id: 'global' },
    });

    const response = config || DEFAULT_CONFIG;

    return NextResponse.json(
      {
        success: true,
        config: response,
      },
      {
        headers: {
          'Cache-Control': 'public, max-age=300, stale-while-revalidate=60',
        },
      }
    );
  } catch (error: any) {
    console.warn('[AdConfig API] Error fetching ad configuration; serving default fallback:', error?.message);
    return NextResponse.json(
      {
        success: true,
        config: DEFAULT_CONFIG,
      },
      { status: 200 }
    );
  }
}
