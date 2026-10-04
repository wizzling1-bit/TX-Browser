import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getAuthenticatedAdmin } from '@/lib/auth';
import { z } from 'zod';

export const dynamic = 'force-dynamic';

const updateFeedbackSchema = z.object({
  status: z.enum(['NEW', 'IN_REVIEW', 'RESOLVED', 'DISMISSED']).optional(),
  adminNotes: z.string().optional().nullable(),
});

export async function PATCH(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { id } = params;
    const body = await req.json();
    const parsed = updateFeedbackSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ error: 'Validation failed', details: parsed.error.format() }, { status: 400 });
    }

    const updated = await prisma.userFeedback.update({
      where: { id },
      data: parsed.data,
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'UPDATE_FEEDBACK_STATUS',
        resourceType: 'UserFeedback',
        resourceId: id,
        metadata: parsed.data,
      },
    });

    return NextResponse.json({ success: true, feedback: updated });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to update feedback' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const admin = await getAuthenticatedAdmin(req);
  if (!admin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { id } = params;
    await prisma.userFeedback.delete({
      where: { id },
    });

    await prisma.adminAuditLog.create({
      data: {
        adminUserId: admin.id,
        action: 'DELETE_USER_FEEDBACK',
        resourceType: 'UserFeedback',
        resourceId: id,
      },
    });

    return NextResponse.json({ success: true, message: 'Feedback entry deleted' });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || 'Failed to delete feedback' }, { status: 500 });
  }
}

