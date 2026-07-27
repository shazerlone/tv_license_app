-- CreateEnum
CREATE TYPE "PositionStatus" AS ENUM ('active', 'closed');

-- CreateTable
CREATE TABLE "CopyConfig" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "traderId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "risk" DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    "autoCopy" BOOLEAN NOT NULL DEFAULT true,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "stoppedAt" TIMESTAMP(3),

    CONSTRAINT "CopyConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CopyPosition" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "traderId" TEXT NOT NULL,
    "traderName" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "pair" TEXT NOT NULL,
    "isBuy" BOOLEAN NOT NULL,
    "status" "PositionStatus" NOT NULL DEFAULT 'active',
    "entryPrice" DOUBLE PRECISION NOT NULL,
    "exitPrice" DOUBLE PRECISION,
    "lots" DOUBLE PRECISION NOT NULL,
    "pnlAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "pnlPercent" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" TIMESTAMP(3),

    CONSTRAINT "CopyPosition_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CopyConfig_userId_idx" ON "CopyConfig"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "CopyConfig_userId_traderId_key" ON "CopyConfig"("userId", "traderId");

-- CreateIndex
CREATE INDEX "CopyPosition_userId_status_idx" ON "CopyPosition"("userId", "status");

-- AddForeignKey
ALTER TABLE "CopyConfig" ADD CONSTRAINT "CopyConfig_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CopyPosition" ADD CONSTRAINT "CopyPosition_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
