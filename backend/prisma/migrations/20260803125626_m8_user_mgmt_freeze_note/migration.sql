-- AlterTable
ALTER TABLE "User" ADD COLUMN     "adminNote" TEXT,
ADD COLUMN     "frozen" BOOLEAN NOT NULL DEFAULT false;
