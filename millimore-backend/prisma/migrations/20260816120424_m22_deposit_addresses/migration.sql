-- CreateTable
CREATE TABLE "DepositAddress" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "network" TEXT NOT NULL,
    "asset" TEXT NOT NULL DEFAULT 'USDT',
    "address" TEXT NOT NULL,
    "providerRef" TEXT,
    "derivationIndex" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DepositAddress_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DepositAddress_address_idx" ON "DepositAddress"("address");

-- CreateIndex
CREATE UNIQUE INDEX "DepositAddress_userId_network_key" ON "DepositAddress"("userId", "network");

-- CreateIndex
CREATE UNIQUE INDEX "DepositAddress_network_address_key" ON "DepositAddress"("network", "address");

