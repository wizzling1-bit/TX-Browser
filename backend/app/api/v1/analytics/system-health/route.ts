import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const startDb = Date.now();
  let dbStatus = 'connected';
  let dbLatencyMs = 0;
  let deviceCount = 0;

  try {
    await prisma.$queryRaw`SELECT 1`;
    dbLatencyMs = Date.now() - startDb;
    deviceCount = await prisma.deviceInstallation.count();
  } catch {
    dbStatus = 'disconnected';
  }

  return NextResponse.json({
    status: dbStatus === 'connected' ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
    database: {
      provider: 'Supabase PostgreSQL Cloud',
      status: dbStatus,
      latencyMs: dbLatencyMs,
      registeredDevices: deviceCount,
      region: 'ap-south-1',
    },
    firebase: {
      projectId: 'tx-browser',
      status: 'connected',
      gateway: 'FCM HTTP v1 Standard (Serverless SDK)',
      clientEmail: 'firebase-adminsdk-fbsvc@tx-browser.iam.gserviceaccount.com',
    },
    syncTopology: {
      appLoginRequired: false,
      deviceIdentity: 'Anonymous Hardware UUID',
      cloudSync: 'Direct Next.js Serverless Edge / Node Runtime',
    },
  });
}
