-- AlterTable
ALTER TABLE "Post" ADD COLUMN     "imageUrl" TEXT,
ADD COLUMN     "tradeEntryPrice" DOUBLE PRECISION,
ADD COLUMN     "tradeEntryType" TEXT,
ADD COLUMN     "tradeSide" TEXT,
ADD COLUMN     "tradeSl" DOUBLE PRECISION,
ADD COLUMN     "tradeSlPct" DOUBLE PRECISION,
ADD COLUMN     "tradeTp" DOUBLE PRECISION,
ADD COLUMN     "tradeTpPct" DOUBLE PRECISION;

-- CreateTable
CREATE TABLE "PairChat" (
    "id" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PairChat_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PairChat_symbol_createdAt_idx" ON "PairChat"("symbol", "createdAt");

