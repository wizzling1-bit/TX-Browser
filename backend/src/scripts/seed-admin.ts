import { prisma } from '../db/prisma.js';
import { authService } from '../services/auth.service.js';
import { env } from '../config/env.js';

async function main() {
  console.log('Seeding initial Super Admin...');

  const email = env.SEED_ADMIN_EMAIL.toLowerCase().trim();
  const existing = await prisma.adminUser.findUnique({
    where: { email },
  });

  if (existing) {
    console.log(`Admin user '${email}' already exists (ID: ${existing.id}).`);
    return;
  }

  const passwordHash = await authService.hashPassword(env.SEED_ADMIN_PASSWORD);

  const admin = await prisma.adminUser.create({
    data: {
      email,
      name: env.SEED_ADMIN_NAME,
      passwordHash,
      role: 'SUPER_ADMIN',
      isActive: true,
    },
  });

  console.log(`Super Admin '${admin.email}' created successfully (ID: ${admin.id}, Role: ${admin.role})`);
}

main()
  .catch((e) => {
    console.error('Failed to seed admin:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
