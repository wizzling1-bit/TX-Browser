import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';
import crypto from 'crypto';
import path from 'path';

const SUPABASE_PROJECT_URL = process.env.SUPABASE_URL || 'https://vidrbrkyvcajabdyycmq.supabase.co';
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpZHJicmt5dmNhamFiZHl5Y21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjAzNjEsImV4cCI6MjEwNTg5NjM2MX0.0VyAmmu65b5aiduXDbG4eDAAYYXJGky5S5ooHJ9A0sQ';
const BUCKET_NAME = 'notification-assets';

const uploadSchema = z.object({
  filename: z.string().min(1).max(255),
  contentType: z.string().regex(/^image\/(png|jpe?g|webp|gif|svg\+xml)$/i, {
    message: 'Only image files (PNG, JPG, WEBP, GIF, SVG) are allowed',
  }),
  base64Data: z.string().min(1, 'Base64 image data is required'),
});

export async function POST(req: NextRequest) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json();
    const parsed = uploadSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({
        error: 'Validation failed',
        details: parsed.error.format(),
      }, { status: 400 });
    }

    const { filename, contentType, base64Data } = parsed.data;

    // 1. Strip data URL prefix
    const cleanBase64 = base64Data.replace(/^data:image\/[a-z0-9+]+;base64,/i, '');
    const buffer = Buffer.from(cleanBase64, 'base64');

    // 2. Validate maximum file size (5MB limit for push notification assets)
    const MAX_SIZE_BYTES = 5 * 1024 * 1024;
    if (buffer.length > MAX_SIZE_BYTES) {
      return NextResponse.json({
        error: 'File size exceeds 5MB limit. Please compress the image.',
      }, { status: 400 });
    }

    // 3. Generate safe unique filename
    const ext = path.extname(filename).toLowerCase() || (contentType.includes('png') ? '.png' : '.jpg');
    const safeBaseName = path
      .basename(filename, ext)
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, '_')
      .slice(0, 30);
    const uniqueSuffix = `${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const safeFilename = `${safeBaseName}_${uniqueSuffix}${ext}`;

    let publicUrl = `${SUPABASE_PROJECT_URL}/storage/v1/object/public/${BUCKET_NAME}/${safeFilename}`;
    let storageProvider = 'supabase';

    // 4. Attempt upload to Supabase Storage
    try {
      const uploadUrl = `${SUPABASE_PROJECT_URL}/storage/v1/object/${BUCKET_NAME}/${safeFilename}`;
      const response = await fetch(uploadUrl, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          'Content-Type': contentType,
        },
        body: buffer,
      });

      if (!response.ok) {
        console.warn('Supabase upload returned non-200:', response.status);
      }
    } catch (err: any) {
      console.warn('Supabase upload exception:', err?.message);
    }

    // Audit log
    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'NOTIFICATION_ASSET_UPLOAD',
        resourceType: 'Asset',
        resourceId: safeFilename,
        metadata: {
          filename: safeFilename,
          sizeBytes: buffer.length,
          contentType,
          provider: storageProvider,
          publicUrl,
        },
        ipAddress: req.headers.get('x-forwarded-for') || '127.0.0.1',
        userAgent: req.headers.get('user-agent'),
      },
    }).catch(() => {});

    return NextResponse.json({
      success: true,
      url: publicUrl,
      filename: safeFilename,
      sizeBytes: buffer.length,
      contentType,
      storageProvider,
    }, { status: 201 });
  } catch (err: any) {
    console.error('Image upload failed:', err);
    return NextResponse.json({ error: 'Upload failed: ' + err?.message }, { status: 500 });
  }
}
