/**
 * Seed / mock data so the app + admin can integrate immediately.
 * Milestone 1: users (admin, demo trader/creator, followers) + a pending
 * creator application for the admin approval queue (milestone 2).
 *
 * Run: npm run db:seed   (idempotent — upserts by stable ids)
 */
import { PrismaClient, Role, CreatorStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('password', 10);

  // Admin — the only way into the admin dashboard.
  await prisma.user.upsert({
    where: { id: 'u_admin' },
    update: {},
    create: {
      id: 'u_admin',
      name: 'Millimore Admin',
      username: 'admin',
      email: 'admin@millimore.app',
      passwordHash: password,
      role: Role.admin,
      creatorStatus: CreatorStatus.none,
      residenceIso: 'AE',
      residenceCountry: 'United Arab Emirates',
    },
  });

  // Demo trader/creator — matches the app's demo login `trader@millimore.app`.
  await prisma.user.upsert({
    where: { id: 'u_marcus' },
    update: {},
    create: {
      id: 'u_marcus',
      name: 'Marcus Sterling',
      username: 'marcussterling',
      email: 'trader@millimore.app',
      phone: '+971 50 000 0001',
      passwordHash: password,
      role: Role.creator,
      creatorStatus: CreatorStatus.approved,
      residenceIso: 'AE',
      residenceCountry: 'United Arab Emirates',
      market: 'Forex',
      platform: 'MetaTrader 5',
    },
  });

  // A follower.
  await prisma.user.upsert({
    where: { id: 'u_priya' },
    update: {},
    create: {
      id: 'u_priya',
      name: 'Priya Sharma',
      username: 'priyatrades',
      email: 'priya@millimore.app',
      phone: '+91 90000 00001',
      passwordHash: password,
      role: Role.follower,
      creatorStatus: CreatorStatus.none,
      residenceIso: 'IN',
      residenceCountry: 'India',
      experience: 'beginner',
      interests: ['Forex', 'Gold'],
    },
  });

  // A creator awaiting approval — populates the admin verification queue.
  await prisma.user.upsert({
    where: { id: 'u_aisha' },
    update: {},
    create: {
      id: 'u_aisha',
      name: 'Aisha Khan',
      username: 'aishafx',
      phone: '+92 300 0000001',
      role: Role.creator,
      creatorStatus: CreatorStatus.pending,
      residenceIso: 'PK',
      residenceCountry: 'Pakistan',
      market: 'Forex',
      platform: 'MetaTrader 4',
    },
  });
  await prisma.creatorApplication.upsert({
    where: { id: 'capp_aisha' },
    update: {},
    create: {
      id: 'capp_aisha',
      userId: 'u_aisha',
      status: CreatorStatus.pending,
      market: 'Forex',
      platform: 'MetaTrader 4',
      verificationPlatform: 'MetaTrader 4',
      server: 'Exness-Real',
      account: '10023498',
      statementUrl: 'https://storage.millimore.app/statements/aisha.pdf',
    },
  });

  // ── Brokers (country-gated list for GET /brokers?country=) ──────────
  const brokers = [
    {
      id: 'century',
      name: 'Century',
      domain: 'centuryfinancial.ae',
      logoUrl: 'https://logo.clearbit.com/centuryfinancial.ae',
      recommended: true,
      countries: ['AE', 'SA', 'IN'],
      sortOrder: 1,
    },
    {
      id: 'xm',
      name: 'XM',
      domain: 'xm.com',
      logoUrl: 'https://logo.clearbit.com/xm.com',
      recommended: true,
      countries: [], // global
      sortOrder: 2,
    },
    {
      id: 'exness',
      name: 'Exness',
      domain: 'exness.com',
      logoUrl: 'https://logo.clearbit.com/exness.com',
      recommended: false,
      countries: [], // global
      sortOrder: 3,
    },
    {
      id: 'icmarkets',
      name: 'IC Markets',
      domain: 'icmarkets.com',
      logoUrl: 'https://logo.clearbit.com/icmarkets.com',
      recommended: false,
      countries: ['AU', 'IN', 'ZA', 'MY'],
      sortOrder: 4,
    },
    {
      id: 'pepperstone',
      name: 'Pepperstone',
      domain: 'pepperstone.com',
      logoUrl: 'https://logo.clearbit.com/pepperstone.com',
      recommended: false,
      countries: ['AU', 'GB', 'AE'],
      sortOrder: 5,
    },
  ];
  for (const b of brokers) {
    await prisma.broker.upsert({ where: { id: b.id }, update: b, create: b });
  }

  // ── A demo connected trading account for the follower ───────────────
  await prisma.tradingAccount.upsert({
    where: { id: 'acc_demo' },
    update: {},
    create: {
      id: 'acc_demo',
      userId: 'u_priya',
      brokerId: 'xm',
      brokerName: 'XM',
      accountNumber: '50231487',
      server: 'XM-Live3',
      currency: 'USD',
      balance: 5000,
      status: 'connected',
    },
  });

  // eslint-disable-next-line no-console
  console.log('Seed complete:');
  console.log('  admin@millimore.app  / password   (admin)');
  console.log('  trader@millimore.app / password   (creator, approved)');
  console.log('  priya@millimore.app  / password   (follower)');
  console.log('  1 pending creator application (Aisha Khan) for the approval queue');
  console.log(`  ${brokers.length} brokers + 1 demo trading account (XM ••••1487)`);
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
