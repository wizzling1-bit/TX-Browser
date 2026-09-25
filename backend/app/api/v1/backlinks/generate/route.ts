import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { buildPlayStoreBacklink } from '@/lib/backlink';

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const { targetUrl, campaignSlug, packageName } = body || {};

    if (!targetUrl || typeof targetUrl !== 'string' || !targetUrl.trim()) {
      return NextResponse.json({
        error: 'Target URL is required (e.g. https://www.example.com/videos/)',
      }, { status: 400 });
    }

    const generated = buildPlayStoreBacklink(targetUrl, campaignSlug, packageName);
    return NextResponse.json(generated);
  } catch (err: any) {
    return NextResponse.json({ error: 'Failed to generate backlink: ' + err?.message }, { status: 400 });
  }
}
