/**
 * Pre-generate per-network USDT deposit addresses for every EXISTING KYC-verified
 * user (so they don't have to be the first to call GET /deposits/addresses).
 * No-op unless a real address provider is configured (CRYPTO_ADDRESS_PROVIDER).
 * Idempotent — skips users/networks that already have an address.
 *
 * Run: CRYPTO_ADDRESS_PROVIDER=tatum … npm run db:backfill-addresses
 */
import { PrismaClient } from '@prisma/client';
import { CryptoAddressService } from '../src/wallet/crypto/crypto-address.service';
import { genId } from '../src/common/ids';

const prisma = new PrismaClient();

async function main() {
  const svc = new CryptoAddressService();
  if (!svc.enabled) {
    console.log('No address provider configured (CRYPTO_ADDRESS_PROVIDER) — nothing to backfill.');
    return;
  }
  console.log(`Backfilling deposit addresses via "${svc.name}" for networks: ${svc.networks.join(', ')}`);

  const users = await prisma.user.findMany({ where: { kycStatus: 'verified' }, select: { id: true } });
  let created = 0;
  for (const u of users) {
    for (const network of svc.networks) {
      const exists = await prisma.depositAddress.findUnique({ where: { userId_network: { userId: u.id, network } } });
      if (exists) continue;
      try {
        const gen = await svc.createAddress(u.id, network);
        await prisma.depositAddress.create({
          data: { id: genId('da'), userId: u.id, network, asset: 'USDT', address: gen.address, providerRef: gen.providerRef, derivationIndex: gen.derivationIndex },
        });
        created++;
      } catch (e) {
        console.warn(`  ${u.id}/${network}: ${(e as Error).message.split('\n')[0]}`);
      }
    }
  }
  console.log(`Done. ${users.length} verified users, ${created} new addresses created.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
