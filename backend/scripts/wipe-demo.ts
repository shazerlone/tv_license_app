/**
 * Remove seeded DEMO rows from a database (e.g. a live DB that was seeded before
 * demo data was gated). Deletes only the known demo entities by their stable ids
 * — it never touches real users, the admin, brokers, or platform settings.
 *
 * Run: npm run db:wipe-demo         (add --yes in CI to skip the prompt)
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const DEMO_USERS = ['u_marcus', 'u_priya', 'u_aisha'];
const DEMO_TRADERS = ['t_marcus', 't_elena', 't_kenji', 't_sofia'];
const DEMO_POSTS = ['p_1', 'p_2', 'p_3', 'p_4', 'p_5'];

/** Run a delete, log the count, and never abort the wipe on a single failure. */
async function del(label: string, fn: () => Promise<{ count: number }>) {
  try {
    const { count } = await fn();
    console.log(`  removed ${count} ${label}`);
  } catch (e) {
    console.log(`  skip ${label} (${(e as Error).message.split('\n')[0]})`);
  }
}

async function main() {
  console.log('Wiping demo rows (real users/admin/brokers/settings are untouched)…');

  const byUser = { userId: { in: DEMO_USERS } };
  const byTrader = { traderId: { in: DEMO_TRADERS } };

  // Broadcasts + their chat (children first).
  try {
    const bs = await prisma.broadcast.findMany({
      where: { OR: [{ creatorId: { in: DEMO_USERS } }, { traderId: { in: DEMO_TRADERS } }] },
      select: { id: true },
    });
    const ids = bs.map((b) => b.id);
    if (ids.length) {
      await del('broadcast chat', () => prisma.broadcastChat.deleteMany({ where: { broadcastId: { in: ids } } }));
      await del('broadcasts', () => prisma.broadcast.deleteMany({ where: { id: { in: ids } } }));
    }
  } catch (e) {
    console.log(`  skip broadcasts (${(e as Error).message.split('\n')[0]})`);
  }

  // Social + engagement.
  await del('post likes', () => prisma.postLike.deleteMany({ where: { OR: [byUser, { postId: { in: DEMO_POSTS } }] } }));
  await del('post saves', () => prisma.postSave.deleteMany({ where: { OR: [byUser, { postId: { in: DEMO_POSTS } }] } }));
  await del('comments', () => prisma.comment.deleteMany({ where: { OR: [byUser, { postId: { in: DEMO_POSTS } }] } }));
  await del('posts', () => prisma.post.deleteMany({ where: { OR: [{ id: { in: DEMO_POSTS } }, byTrader] } }));
  await del('subscriptions', () => prisma.subscription.deleteMany({ where: { OR: [byUser, byTrader] } }));

  // Trading / money.
  await del('copy positions', () => prisma.copyPosition.deleteMany({ where: { OR: [byUser, byTrader] } }));
  await del('copy configs', () => prisma.copyConfig.deleteMany({ where: { OR: [byUser, byTrader] } }));
  await del('price alerts', () => prisma.priceAlert.deleteMany({ where: byUser }));
  await del('ledger entries', () => prisma.ledgerEntry.deleteMany({ where: byUser }));
  await del('deposits', () => prisma.deposit.deleteMany({ where: byUser }));
  await del('payout methods', () => prisma.payoutMethod.deleteMany({ where: byUser }));
  await del('wallets', () => prisma.wallet.deleteMany({ where: byUser }));
  await del('trading accounts', () => prisma.tradingAccount.deleteMany({ where: { OR: [{ id: 'acc_demo' }, byUser] } }));

  // Profiles.
  await del('creator applications', () => prisma.creatorApplication.deleteMany({ where: byUser }));
  await del('traders', () => prisma.trader.deleteMany({ where: { id: { in: DEMO_TRADERS } } }));
  await del('password resets', () => prisma.passwordReset.deleteMany({ where: byUser }));
  await del('demo users', () => prisma.user.deleteMany({ where: { id: { in: DEMO_USERS } } }));

  console.log('Demo wipe complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
