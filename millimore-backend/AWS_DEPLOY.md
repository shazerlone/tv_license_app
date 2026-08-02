# Deploying Millimore to AWS

Straight answer to "is the backend ready for AWS?": **yes.** It's a stateless
container, all config is env-vars, Postgres is swappable, and the realtime layer
now fans out across many instances via Redis (proven with a 2-instance test).
This is the runbook.

## Recommended architecture (scales to millions, start small)

```
            ┌──────────────┐
  phone ───▶│     ALB      │  (HTTPS + WebSocket)
  admin ───▶│ (Application │
            │ Load Balancer)│
            └──────┬───────┘
                   │  many identical tasks (start with 1, autoscale 1→N)
            ┌──────▼───────┐
            │ ECS Fargate  │  ← the Millimore container (this repo's Dockerfile)
            └──┬────────┬──┘
               │        │
      ┌────────▼──┐  ┌──▼───────────┐
      │ RDS/Aurora│  │ ElastiCache  │
      │ Postgres  │  │   (Redis)    │
      └───────────┘  └──────────────┘
                       + S3+CloudFront (uploads/admin) — optional upgrade
```

Why Fargate+ALB (not App Runner): the app is **WebSocket-heavy** (live prices,
portfolio, chat). ALB supports WebSockets reliably; App Runner's WS support is
limited. Fargate is also the natural autoscaling target.

## What's already done (no code changes needed)
- ✅ **Stateless container** — `Dockerfile` (non-root, healthcheck, `0.0.0.0`).
- ✅ **12-factor config** — every setting is an env var → SSM/Secrets Manager.
- ✅ **Postgres via Prisma** — point `DATABASE_URL` at Aurora/RDS; nothing else changes.
- ✅ **Multi-instance realtime** — set `REDIS_URL` (ElastiCache) and events +
  prices fan out across all tasks. A single price "leader" is elected via Redis
  so every instance shows identical prices. (Verified: an event triggered on
  task B was delivered to a WebSocket client on task A.)
- ✅ **Graceful shutdown** — `SIGTERM` drains cleanly for rolling deploys.

## Uploads → S3 (implemented, env-gated)
- Set `STORAGE_BUCKET` + `STORAGE_REGION` and uploads go to **S3** (served via
  `STORAGE_PUBLIC_BASE_URL`/CloudFront, or the S3 URL). Unset = Postgres bytes
  (fine for dev/one node). No code change — just env + a bucket + IAM permission.
- On Fargate, **leave the S3 access keys blank** and attach an IAM task role with
  `s3:PutObject` on the bucket; the SDK uses the role automatically (best practice).

---

## Step-by-step (the easy path: AWS Copilot)

Copilot builds the VPC + ALB + ECS + autoscaling + logs from one manifest.

**0. Prereqs:** an AWS account, the AWS CLI (`aws configure` with your keys), and
`copilot` CLI installed. Do this from `millimore-backend/`.

**1. Managed data stores (once):**
- **RDS Postgres** (or Aurora Serverless v2): create a `millimore` database.
  Note its connection string → `postgresql://USER:PASS@HOST:5432/millimore?schema=public&sslmode=require`.
- **ElastiCache for Redis** (cluster mode off, 1 node to start): note its URL →
  `redis://HOST:6379`.
- Put both, plus generated secrets, in SSM Parameter Store:
  ```bash
  copilot secret init --name DATABASE_URL              # paste the RDS URL
  copilot secret init --name REDIS_URL                 # paste the ElastiCache URL
  copilot secret init --name JWT_SECRET                # openssl rand -hex 32
  copilot secret init --name CREDENTIAL_ENCRYPTION_KEY # openssl rand -base64 32  (KEEP STABLE)
  ```
- **S3 for uploads (optional but recommended):** create a bucket
  (`aws s3 mb s3://millimore-uploads-prod`), allow public read (or front it with
  CloudFront), then add to the Copilot manifest `variables:`
  `STORAGE_BUCKET: millimore-uploads-prod`, `STORAGE_REGION: <region>`, and grant
  the task role `s3:PutObject`. Leave the access-key env vars unset (IAM role).

**2. Initialize + deploy the service:**
```bash
copilot init --app millimore --name backend \
  --type "Load Balanced Web Service" --dockerfile ./Dockerfile --port 3000
# replace copilot/backend/manifest.yml with deploy/aws/copilot-manifest.yml (adjust secret paths)
copilot env init --name prod
copilot deploy --name backend --env prod
```
Copilot prints your public URL (e.g. `https://millimore-...elb.amazonaws.com`).

**3. Run migrations once per deploy** (don't run on every task boot):
```bash
copilot svc exec -a millimore -e prod -n backend -c "npx prisma migrate deploy && npm run db:seed"
```

**4. Point clients at it:**
- App: base URL `https://<alb-domain>/v1`, WebSocket `wss://<alb-domain>/v1/ws`.
- Admin UI is served at `https://<alb-domain>/` (single-origin).
- Add a custom domain (`api.millimore.app`) + ACM cert on the ALB when ready.

## Costs (with your credits)
A minimal always-on setup — 1 Fargate task (0.5 vCPU/1GB) + `db.t4g.micro` RDS +
`cache.t4g.micro` Redis + ALB — is roughly **$50–90/month**, well within typical
credits. Autoscaling adds cost only under real load. No cold starts (unlike free
Render). Turn tasks/replicas up when metrics justify it — see `ARCHITECTURE.md`.

## Advisor note
You don't need the full multi-instance setup on day one — **1 Fargate task + RDS**
already removes cold starts and gives you a real, always-on environment. Add
ElastiCache + autoscaling (both already supported by the code) the moment traffic
grows. Each step is a config change, not a rewrite. If you want, a DevOps person
can run the steps above in ~an afternoon; this doc + the Dockerfile + the Copilot
manifest are exactly what they need.
