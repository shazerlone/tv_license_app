-- CreateTable
CREATE TABLE "PriceAlert" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "direction" TEXT NOT NULL,
    "targetPrice" DOUBLE PRECISION NOT NULL,
    "note" TEXT,
    "notifyEmail" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'active',
    "triggeredAt" TIMESTAMP(3),
    "triggeredPrice" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PriceAlert_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PriceAlert_userId_status_idx" ON "PriceAlert"("userId", "status");

-- CreateIndex
CREATE INDEX "PriceAlert_status_symbol_idx" ON "PriceAlert"("status", "symbol");

