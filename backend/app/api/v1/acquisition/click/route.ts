import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const campaignSlug = searchParams.get('campaign') || searchParams.get('slug') || 'promo18';
    const redirectUrl = searchParams.get('target') || searchParams.get('url');

    const ipAddress = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown';
    const userAgent = req.headers.get('user-agent') || 'unknown';

    // Record click event
    await prisma.campaignClickEvent.create({
      data: {
        campaignSlug,
        targetUrl: redirectUrl || 'https://play.google.com/store/apps/details?id=com.wizzling.tx_browser',
        ipAddress: ipAddress.split(',')[0].trim(),
        userAgent,
      },
    });

    // Increment click count on backlink if exists
    await prisma.campaignBacklink.updateMany({
      where: { campaignSlug },
      data: {
        clickCount: { increment: 1 },
      },
    });

    if (redirectUrl) {
      return NextResponse.redirect(redirectUrl, { status: 302 });
    }

    return NextResponse.json({
      success: true,
      campaign: campaignSlug,
      recordedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    console.error('[Acquisition Click API] Error:', error);
    return NextResponse.json({ success: false, error: error?.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const campaignSlug = body.campaignSlug || body.campaign || 'promo18';
    const targetUrl = body.targetUrl || body.url || 'https://play.google.com/store/apps/details?id=com.wizzling.tx_browser';

    const ipAddress = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown';
    const userAgent = req.headers.get('user-agent') || 'unknown';

    await prisma.campaignClickEvent.create({
      data: {
        campaignSlug,
        targetUrl,
        ipAddress: ipAddress.split(',')[0].trim(),
        userAgent,
      },
    });

    await prisma.campaignBacklink.updateMany({
      where: { campaignSlug },
      data: {
        clickCount: { increment: 1 },
      },
    });

    return NextResponse.json({
      success: true,
      campaignSlug,
      recordedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error?.message }, { status: 500 });
  }
}
