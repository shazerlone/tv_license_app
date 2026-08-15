/**
 * Seed data.
 *
 * Production-safe: only reference data (brokers, platform settings) and a real
 * admin (from ADMIN_EMAIL / ADMIN_PASSWORD) are seeded by default. All demo
 * content — fake creators, traders, posts, live flags, pre-funded wallets — is
 * gated behind SEED_DEMO=true and must NEVER run in production. To remove demo
 * rows already in a live DB, run `npm run db:wipe-demo`.
 *
 * Run: SEED_DEMO=true npm run db:seed   (dev)   ·   npm run db:seed   (prod)
 */
import { PrismaClient, Role, CreatorStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();
const SEED_DEMO = process.env.SEED_DEMO === 'true';

/** Real admin from env (prod); the demo admin only exists with SEED_DEMO. */
async function seedAdmin() {
  const email = process.env.ADMIN_EMAIL?.trim() || (SEED_DEMO ? 'admin@millimore.app' : undefined);
  const pw = process.env.ADMIN_PASSWORD || (SEED_DEMO ? 'password' : undefined);
  if (!email || !pw) {
    console.log('  admin: none (set ADMIN_EMAIL + ADMIN_PASSWORD to create one)');
    return;
  }
  const passwordHash = await bcrypt.hash(pw, 10);
  await prisma.user.upsert({
    where: { id: 'u_admin' },
    update: { email, passwordHash, role: Role.admin, adminRole: 'superadmin' },
    create: {
      id: 'u_admin',
      name: 'Millimore Admin',
      username: 'admin',
      email,
      passwordHash,
      role: Role.admin,
      adminRole: 'superadmin',
      creatorStatus: CreatorStatus.none,
      residenceIso: 'AE',
      residenceCountry: 'United Arab Emirates',
    },
  });
  console.log(`  admin: ${email}`);
}

/** Country-gated broker list (reference data — always seeded). */
async function seedBrokers(): Promise<number> {
  const brokers = [
    { id: 'century', name: 'Century', domain: 'centuryfinancial.ae', logoUrl: 'https://logo.clearbit.com/centuryfinancial.ae', recommended: true, countries: ['AE', 'SA', 'IN'], sortOrder: 1 },
    { id: 'xm', name: 'XM', domain: 'xm.com', logoUrl: 'https://logo.clearbit.com/xm.com', recommended: true, countries: [], sortOrder: 2 },
    { id: 'exness', name: 'Exness', domain: 'exness.com', logoUrl: 'https://logo.clearbit.com/exness.com', recommended: false, countries: [], sortOrder: 3 },
    { id: 'icmarkets', name: 'IC Markets', domain: 'icmarkets.com', logoUrl: 'https://logo.clearbit.com/icmarkets.com', recommended: false, countries: ['AU', 'IN', 'ZA', 'MY'], sortOrder: 4 },
    { id: 'pepperstone', name: 'Pepperstone', domain: 'pepperstone.com', logoUrl: 'https://logo.clearbit.com/pepperstone.com', recommended: false, countries: ['AU', 'GB', 'AE'], sortOrder: 5 },
  ];
  for (const b of brokers) {
    await prisma.broker.upsert({ where: { id: b.id }, update: b, create: b });
  }
  return brokers.length;
}

/** Platform settings singleton (always seeded). */
async function seedSettings() {
  await prisma.platformSettings.upsert({ where: { id: 'platform' }, update: {}, create: { id: 'platform' } });
}

/** Every approved creator gets a public Trader profile (safe in prod: no-op when
 *  there are no approved creators yet). isLive is never set here. */
async function backfillTraderProfiles() {
  const approved = await prisma.user.findMany({
    where: { role: 'creator', creatorStatus: 'approved', trader: { is: null } },
  });
  for (const u of approved) {
    await prisma.trader.create({
      data: {
        id: `t_${u.id.replace(/^u_/, '')}`,
        userId: u.id,
        name: u.name,
        username: u.username,
        photoUrl: u.photoUrl,
        isVerified: true,
        category: u.market ?? 'Forex',
      },
    });
  }
}

/** All demo content — gated behind SEED_DEMO, never in production. */
async function seedDemo() {
  const password = await bcrypt.hash('password', 10);

  // Demo creator (app's demo login trader@millimore.app), a follower, and a
  // pending creator for the admin verification queue.
  await prisma.user.upsert({
    where: { id: 'u_marcus' },
    update: {},
    create: { id: 'u_marcus', name: 'Marcus Sterling', username: 'marcussterling', email: 'trader@millimore.app', phone: '+971 50 000 0001', passwordHash: password, role: Role.creator, creatorStatus: CreatorStatus.approved, residenceIso: 'AE', residenceCountry: 'United Arab Emirates', market: 'Forex', platform: 'MetaTrader 5' },
  });
  await prisma.user.upsert({
    where: { id: 'u_priya' },
    update: {},
    create: { id: 'u_priya', name: 'Priya Sharma', username: 'priyatrades', email: 'priya@millimore.app', phone: '+91 90000 00001', passwordHash: password, role: Role.follower, creatorStatus: CreatorStatus.none, residenceIso: 'IN', residenceCountry: 'India', experience: 'beginner', interests: ['Forex', 'Gold'] },
  });
  await prisma.user.upsert({
    where: { id: 'u_aisha' },
    update: {},
    create: { id: 'u_aisha', name: 'Aisha Khan', username: 'aishafx', phone: '+92 300 0000001', role: Role.creator, creatorStatus: CreatorStatus.pending, residenceIso: 'PK', residenceCountry: 'Pakistan', market: 'Forex', platform: 'MetaTrader 4' },
  });
  await prisma.creatorApplication.upsert({
    where: { id: 'capp_aisha' },
    update: {},
    create: { id: 'capp_aisha', userId: 'u_aisha', status: CreatorStatus.pending, market: 'Forex', platform: 'MetaTrader 4', verificationPlatform: 'MetaTrader 4', server: 'Exness-Real', account: '10023498', statementUrl: 'https://storage.millimore.app/statements/aisha.pdf' },
  });

  // A demo connected trading account for the follower.
  await prisma.tradingAccount.upsert({
    where: { id: 'acc_demo' },
    update: {},
    create: { id: 'acc_demo', userId: 'u_priya', brokerId: 'xm', brokerName: 'XM', accountNumber: '50231487', server: 'XM-Live3', currency: 'USD', balance: 5000, status: 'connected' },
  });

  // Public trader profiles. isLive is ALWAYS false here — it is driven only by
  // real broadcast start/end (see broadcasts.service).
  const traders = [
    { id: 't_marcus', userId: 'u_marcus', name: 'Marcus Sterling', username: 'marcussterling', isVerified: true, isLive: false, returnPercent: 18.45, returnDays: 30, followers: 12400, copiers: 1840, aum: 2300000, winRate: 72, maxDrawdown: 9.2, totalTrades: 612, category: 'Forex', tags: ['Price Action', 'EUR/USD', 'Swing'], bio: 'Full-time FX trader. 8 years on the majors. Risk first, always.' },
    { id: 't_elena', name: 'Elena Voss', username: 'elenavoss', isVerified: true, isLive: false, returnPercent: 24.1, returnDays: 30, followers: 8800, copiers: 1210, aum: 1450000, winRate: 68, maxDrawdown: 12.4, totalTrades: 430, category: 'Crypto', tags: ['BTC', 'Momentum'], bio: 'Crypto momentum & breakout trader. Data over emotion.' },
    { id: 't_kenji', name: 'Kenji Nakamura', username: 'kenjifx', isVerified: true, isLive: false, returnPercent: 11.9, returnDays: 30, followers: 15600, copiers: 2600, aum: 3900000, winRate: 75, maxDrawdown: 6.1, totalTrades: 980, category: 'Gold', tags: ['XAU/USD', 'Scalping', 'London'], bio: 'Gold scalper. London + NY sessions. Consistency compounds.' },
    { id: 't_sofia', name: 'Sofia Marchetti', username: 'sofiam', isVerified: false, isLive: false, returnPercent: 31.7, returnDays: 30, followers: 4200, copiers: 540, aum: 620000, winRate: 61, maxDrawdown: 18.9, totalTrades: 210, category: 'Indices', tags: ['US30', 'NAS100', 'News'], bio: 'Index day-trader. High conviction, high volatility.' },
  ];
  for (const t of traders) {
    await prisma.trader.upsert({ where: { id: t.id }, update: t, create: t });
  }

  const posts = [
    { id: 'p_1', traderId: 't_marcus', type: 'analysis' as const, content: 'EUR/USD reclaimed 1.0850 and is holding above the London high. I like longs on a retest of 1.0840 with stops under 1.0810.', pair: 'EUR/USD', title: 'EUR/USD — reclaim and go', points: ['Above London high', 'Retest 1.0840 for entry', 'Invalidation < 1.0810'] },
    { id: 'p_2', traderId: 't_marcus', type: 'trade' as const, content: 'Long EUR/USD filled at 1.0842. SL 1.0808, TP1 1.0910.', pair: 'EUR/USD', points: [] },
    { id: 'p_3', traderId: 't_kenji', type: 'lesson' as const, content: 'Scalping gold is about session timing. 90% of my trades happen in the first two hours of London. Outside that window, spreads eat you alive.', pair: 'XAU/USD', title: 'Why session timing beats indicators', points: ['Trade the London open', 'Respect the spread', 'Fewer, better setups'] },
    { id: 'p_4', traderId: 't_elena', type: 'analysis' as const, content: 'BTC is coiling under 68k. A daily close above flips the structure bullish; until then I stay patient.', pair: 'BTC/USD', title: 'BTC — patience under resistance', points: ['Watching 68k daily close', 'No FOMO longs'] },
    { id: 'p_5', traderId: 't_sofia', type: 'trade' as const, content: 'Short US30 into the news spike. Quick scalp, booked +140 pts.', pair: 'US30', points: [] },
  ];
  for (const p of posts) {
    await prisma.post.upsert({ where: { id: p.id }, update: p, create: p });
  }

  const comments = [
    { id: 'c_1', postId: 'p_1', userId: 'u_priya', text: 'Clean setup, thanks Marcus!' },
    { id: 'c_2', postId: 'p_1', userId: 'u_aisha', text: 'What timeframe are you watching?' },
    { id: 'c_3', postId: 'p_3', userId: 'u_priya', text: 'This clicked for me. Session timing it is.' },
  ];
  for (const c of comments) {
    await prisma.comment.upsert({ where: { id: c.id }, update: c, create: c });
  }

  // Clean social graph — no seeded follows (feed/subscriptions start empty).
  await prisma.subscription.deleteMany({ where: { userId: 'u_priya' } });
  await prisma.postLike.deleteMany({ where: { userId: 'u_priya' } });
  await prisma.postSave.deleteMany({ where: { userId: 'u_priya' } });

  // Pre-funded demo wallets so deposit → copy → settle works end-to-end.
  const walletSeeds = [
    { userId: 'u_priya', balance: 10000 },
    { userId: 'u_marcus', balance: 2000 },
    { userId: 'u_aisha', balance: 0 },
  ];
  for (const w of walletSeeds) {
    await prisma.wallet.upsert({
      where: { userId: w.userId },
      update: { balance: w.balance },
      create: { id: `w_${w.userId.replace(/^u_/, '')}`, userId: w.userId, balance: w.balance, currency: 'USD' },
    });
  }
  await prisma.deposit.upsert({
    where: { id: 'dep_seed_priya' },
    update: {},
    create: { id: 'dep_seed_priya', userId: 'u_priya', amount: 10000, currency: 'USD', method: 'crypto', asset: 'USDT', status: 'confirmed', confirmedAt: new Date() },
  });
  await prisma.ledgerEntry.upsert({
    where: { id: 'led_seed_priya' },
    update: {},
    create: { id: 'led_seed_priya', userId: 'u_priya', type: 'deposit', amount: 10000, balanceAfter: 10000, currency: 'USD', refId: 'dep_seed_priya', note: 'Seed deposit' },
  });

  // KYC-verify demo users + default leverage so the full flow works in test mode.
  await prisma.user.updateMany({ where: { id: { in: ['u_priya', 'u_marcus'] } }, data: { kycStatus: 'verified', kycProvider: 'manual', leverage: 100 } });

  // Referral demo: Priya was referred by Marcus.
  await prisma.user.update({ where: { id: 'u_marcus' }, data: { referralCode: 'MARCUS1' } });
  await prisma.user.update({ where: { id: 'u_priya' }, data: { referralCode: 'PRIYA01' } });
  await prisma.user.updateMany({ where: { id: 'u_priya' }, data: { referredById: 'u_marcus', referredByCode: 'MARCUS1' } });

  console.log('  DEMO data: 1 creator, 1 follower, 1 pending application, 4 traders, 5 posts, pre-funded wallets');
  console.log('    trader@millimore.app / password   ·   priya@millimore.app / password');
}

async function main() {
  console.log(`Seeding (SEED_DEMO=${SEED_DEMO})…`);
  await seedAdmin();
  const brokerCount = await seedBrokers();
  await seedSettings();
  await backfillTraderProfiles();
  if (SEED_DEMO) {
    await seedDemo();
  } else {
    console.log('  production mode — no demo data (fake creators/broadcasts/wallets skipped)');
  }
  console.log(`Seed complete: ${brokerCount} brokers, settings ready.`);
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
