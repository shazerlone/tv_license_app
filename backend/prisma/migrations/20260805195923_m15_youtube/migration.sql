-- AlterTable
ALTER TABLE "Broadcast" ADD COLUMN     "youtubeLiveChatId" TEXT;

-- CreateTable
CREATE TABLE "YoutubeAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "refreshTokenEnc" TEXT NOT NULL,
    "channelId" TEXT,
    "channelTitle" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "YoutubeAccount_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "YoutubeAccount_userId_key" ON "YoutubeAccount"("userId");

