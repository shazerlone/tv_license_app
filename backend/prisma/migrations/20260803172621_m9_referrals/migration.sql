-- AlterEnum
ALTER TYPE "LedgerType" ADD VALUE 'referral_commission';

-- AlterTable
ALTER TABLE "PlatformSettings" ADD COLUMN     "referralEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "referralRevenueShare" DOUBLE PRECISION NOT NULL DEFAULT 0.10,
ADD COLUMN     "referralSignupBonus" DOUBLE PRECISION NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "referralCode" TEXT,
ADD COLUMN     "referredByCode" TEXT,
ADD COLUMN     "referredById" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "User_referralCode_key" ON "User"("referralCode");

-- CreateIndex
CREATE INDEX "User_referredById_idx" ON "User"("referredById");

