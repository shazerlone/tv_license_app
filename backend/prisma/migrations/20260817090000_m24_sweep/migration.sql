-- CreateTable
CREATE TABLE "Sweep" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "network" TEXT NOT NULL,
    "fromAddress" TEXT NOT NULL,
    "toAddress" TEXT NOT NULL,
    "asset" TEXT NOT NULL DEFAULT 'USDT',
    "amount" DOUBLE PRECISION NOT NULL,
    "txRef" TEXT,
    "signatureId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Sweep_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Sweep_userId_idx" ON "Sweep"("userId");

-- CreateIndex
CREATE INDEX "Sweep_network_fromAddress_idx" ON "Sweep"("network", "fromAddress");

-- CreateIndex
CREATE INDEX "Sweep_status_idx" ON "Sweep"("status");

