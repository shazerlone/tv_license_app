-- CreateEnum
CREATE TYPE "Role" AS ENUM ('follower', 'creator', 'admin');

-- CreateEnum
CREATE TYPE "CreatorStatus" AS ENUM ('none', 'pending', 'approved', 'rejected', 'suspended');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "username" TEXT NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "photoUrl" TEXT,
    "role" "Role" NOT NULL DEFAULT 'follower',
    "creatorStatus" "CreatorStatus" NOT NULL DEFAULT 'none',
    "residenceIso" TEXT,
    "residenceCountry" TEXT,
    "market" TEXT,
    "platform" TEXT,
    "experience" TEXT,
    "interests" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "passwordHash" TEXT,
    "appleSubject" TEXT,
    "googleSubject" TEXT,
    "banned" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtpRequest" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "consumedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OtpRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CreatorApplication" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" "CreatorStatus" NOT NULL DEFAULT 'pending',
    "market" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "verificationPlatform" TEXT NOT NULL,
    "server" TEXT,
    "account" TEXT,
    "statementUrl" TEXT,
    "investorPasswordEnc" TEXT,
    "reviewerNote" TEXT,
    "rejectReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CreatorApplication_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "User_appleSubject_key" ON "User"("appleSubject");

-- CreateIndex
CREATE UNIQUE INDEX "User_googleSubject_key" ON "User"("googleSubject");

-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE INDEX "User_creatorStatus_idx" ON "User"("creatorStatus");

-- CreateIndex
CREATE INDEX "OtpRequest_phone_idx" ON "OtpRequest"("phone");

-- CreateIndex
CREATE INDEX "CreatorApplication_status_idx" ON "CreatorApplication"("status");

-- CreateIndex
CREATE INDEX "CreatorApplication_userId_idx" ON "CreatorApplication"("userId");

-- AddForeignKey
ALTER TABLE "CreatorApplication" ADD CONSTRAINT "CreatorApplication_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
