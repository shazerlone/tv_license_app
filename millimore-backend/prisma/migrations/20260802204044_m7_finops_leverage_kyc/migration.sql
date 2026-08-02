-- CreateEnum
CREATE TYPE "KycStatus" AS ENUM ('none', 'pending', 'verified', 'rejected');

-- AlterTable
ALTER TABLE "CopyConfig" ADD COLUMN     "leverage" INTEGER NOT NULL DEFAULT 100;

-- AlterTable
ALTER TABLE "Deposit" ADD COLUMN     "decisionBy" TEXT,
ADD COLUMN     "flagReason" TEXT,
ADD COLUMN     "flagged" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "reason" TEXT;

-- AlterTable
ALTER TABLE "Payout" ADD COLUMN     "flagReason" TEXT,
ADD COLUMN     "flagged" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "methodId" TEXT;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "addressLine" TEXT,
ADD COLUMN     "city" TEXT,
ADD COLUMN     "kycApplicantId" TEXT,
ADD COLUMN     "kycProvider" TEXT,
ADD COLUMN     "kycReason" TEXT,
ADD COLUMN     "kycStatus" "KycStatus" NOT NULL DEFAULT 'none',
ADD COLUMN     "leverage" INTEGER NOT NULL DEFAULT 100,
ADD COLUMN     "postalCode" TEXT;

-- CreateTable
CREATE TABLE "PlatformSettings" (
    "id" TEXT NOT NULL DEFAULT 'platform',
    "platformFeeShare" DOUBLE PRECISION NOT NULL DEFAULT 0.30,
    "maxLeverage" INTEGER NOT NULL DEFAULT 500,
    "defaultLeverage" INTEGER NOT NULL DEFAULT 100,
    "minDeposit" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "minWithdrawal" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "maxWithdrawalPerTx" DOUBLE PRECISION NOT NULL DEFAULT 25000,
    "maxWithdrawalPerDay" DOUBLE PRECISION NOT NULL DEFAULT 50000,
    "depositAutoConfirm" BOOLEAN NOT NULL DEFAULT true,
    "kycRequiredForWithdrawal" BOOLEAN NOT NULL DEFAULT true,
    "cryptoEnabled" BOOLEAN NOT NULL DEFAULT true,
    "cardEnabled" BOOLEAN NOT NULL DEFAULT false,
    "bankEnabled" BOOLEAN NOT NULL DEFAULT false,
    "maintenanceMode" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlatformSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PayoutMethod" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "detailsEnc" TEXT NOT NULL,
    "masked" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PayoutMethod_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdminAuditLog" (
    "id" TEXT NOT NULL,
    "adminId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "meta" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PayoutMethod_userId_idx" ON "PayoutMethod"("userId");

-- CreateIndex
CREATE INDEX "AdminAuditLog_createdAt_idx" ON "AdminAuditLog"("createdAt");

-- CreateIndex
CREATE INDEX "AdminAuditLog_targetType_targetId_idx" ON "AdminAuditLog"("targetType", "targetId");

-- AddForeignKey
ALTER TABLE "PayoutMethod" ADD CONSTRAINT "PayoutMethod_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
