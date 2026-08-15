-- AlterTable
ALTER TABLE "Deposit" ADD COLUMN     "payAmount" DOUBLE PRECISION,
ADD COLUMN     "payCurrency" TEXT,
ADD COLUMN     "providerRef" TEXT;

