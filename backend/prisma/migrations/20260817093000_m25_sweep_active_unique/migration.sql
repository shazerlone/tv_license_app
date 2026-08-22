-- Prevent two in-flight sweeps for the same address (scale-safe across instances):
-- a second concurrent INSERT with status pending/broadcast fails with a unique
-- violation, which the service catches and treats as "already in flight".
CREATE UNIQUE INDEX "Sweep_active_addr_key"
  ON "Sweep"("network", "fromAddress")
  WHERE "status" IN ('pending', 'broadcast');
