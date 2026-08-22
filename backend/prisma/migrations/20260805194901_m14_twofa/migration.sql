-- AlterTable
ALTER TABLE "User" ADD COLUMN     "twofaBackupCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "twofaEnabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "twofaLastStep" INTEGER,
ADD COLUMN     "twofaSecretEnc" TEXT;

