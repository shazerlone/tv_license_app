-- AlterTable
ALTER TABLE "PlatformSettings" ALTER COLUMN "depositAutoConfirm" SET DEFAULT false;


-- Force existing settings row(s) off (production safety: no auto-credit).
UPDATE "PlatformSettings" SET "depositAutoConfirm" = false;
