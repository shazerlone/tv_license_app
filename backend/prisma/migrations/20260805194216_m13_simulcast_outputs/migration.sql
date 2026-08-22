-- CreateTable
CREATE TABLE "BroadcastOutput" (
    "id" TEXT NOT NULL,
    "broadcastId" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "targetUrl" TEXT NOT NULL,
    "streamKeyEnc" TEXT NOT NULL,
    "masked" TEXT NOT NULL,
    "cfOutputId" TEXT,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BroadcastOutput_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "BroadcastOutput_broadcastId_idx" ON "BroadcastOutput"("broadcastId");

-- AddForeignKey
ALTER TABLE "BroadcastOutput" ADD CONSTRAINT "BroadcastOutput_broadcastId_fkey" FOREIGN KEY ("broadcastId") REFERENCES "Broadcast"("id") ON DELETE CASCADE ON UPDATE CASCADE;

