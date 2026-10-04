const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function grantAll() {
  const sqlStatements = [
    'GRANT USAGE ON SCHEMA public TO anon, authenticated',
    'GRANT SELECT ON public.ad_configurations TO anon, authenticated',
    'GRANT SELECT ON public.security_threats TO anon, authenticated',
    'GRANT INSERT, SELECT ON public.user_feedbacks TO anon, authenticated',
    'GRANT SELECT, INSERT, UPDATE ON public.device_installations TO anon, authenticated',
    'GRANT SELECT, INSERT, DELETE ON public.device_topics TO anon, authenticated',
    'GRANT SELECT ON public.campaign_backlinks TO anon, authenticated',
    'GRANT INSERT ON public.campaign_click_events TO anon, authenticated'
  ];

  for (const sql of sqlStatements) {
    console.log('Running:', sql);
    await prisma.$executeRawUnsafe(sql);
  }
  console.log('All grants applied successfully as tx_admin!');
}

grantAll()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
