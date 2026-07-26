# Millimore — Architecture, Portability & Scaling

Plain-language answer to: *"Can this move to AWS and handle millions of users?"*
**Yes — by design.** We're using the same building blocks that companies at that
scale use, and we've kept clean seams so scaling is mostly **infrastructure and
config, not rewrites.** This doc is the map.

---

## 1. The one idea that makes scaling possible: statelessness

The API keeps **no memory of its own** between requests. Who you are travels in
your login token (JWT); everything else lives in the database, cache, or file
storage — never inside one running server.

Why that matters: to serve more people you just **run more identical copies** of
the API behind a load balancer. 1 copy or 500 copies, same code. This is
"horizontal scaling," and it's the difference between an app that hits a ceiling
and one that grows to millions. We have it from day one.

## 2. What we chose, and why it already belongs at scale

| Piece | What we use now | What it becomes on AWS | Effort to move |
| ----- | --------------- | ---------------------- | -------------- |
| API server | NestJS (Node) in a container | ECS/Fargate or EKS, autoscaled | **Config only** — it's already a container (`Dockerfile`) |
| Database | PostgreSQL | **Amazon Aurora/RDS PostgreSQL** (read replicas, huge scale) | **Change one env var** (`DATABASE_URL`) |
| Cache / realtime bus | Redis | **Amazon ElastiCache** | Change `REDIS_URL` |
| File storage | S3-compatible (env-driven) | **Amazon S3 + CloudFront CDN** | Fill in the `STORAGE_*` vars |
| Admin dashboard | Static site | **S3 + CloudFront** (or stays merged) | Copy a folder |
| Secrets | `.env` / host env vars | **AWS Secrets Manager / SSM** | Same variable names |
| Config | 100% environment variables ([12-factor](https://12factor.net)) | identical | none |

Nothing in that table is a rewrite. That's the whole point of the choices we made.

## 3. What "millions of users" actually needs (and how we're ready)

Scaling isn't one switch; it's a handful of well-understood layers. Here's the
plan and where we already stand:

1. **Many API copies + load balancer** — ✅ enabled today (stateless + Docker).
2. **Managed database with read replicas** — Aurora. We use Prisma, which talks
   to any Postgres, so this is a connection-string change. (Add a connection
   pooler like PgBouncer/RDS Proxy when copies get numerous.)
3. **Caching** — Redis/ElastiCache in front of hot reads. Wired in as milestones 4/5 need it.
4. **Realtime that scales across copies** — WebSockets (prices, live chat,
   portfolio) will use **Redis pub/sub** so any API copy can push to any user.
   Designed in from the start of milestone 4/5.
5. **Background workers + queues** — heavy/slow work (copy-trade execution,
   YouTube chat polling, payouts) runs off the request path via a job queue
   (BullMQ on Redis now → **Amazon SQS**). Keeps the app snappy under load.
6. **CDN for static + media** — CloudFront in front of the admin and S3 assets.
7. **Observability** — structured logs, metrics, tracing, error tracking
   (CloudWatch / Datadog / Sentry) so we can see and fix load problems.
8. **CI/CD** — automated build → test → deploy (GitHub Actions → ECS).

We build these **when traffic justifies them**, not before — see §5.

## 4. The "swap before you scale" list (deliberate shortcuts, all isolated)

To ship fast we took a few shortcuts. Each is **quarantined behind a clean
boundary**, so swapping it is a contained change, not a teardown:

- **OTP by console** → Twilio/MSG91. One provider module (`auth/otp`).
- **Synthetic trader trades/equity** → real MT bridge (MetaApi). One service.
- **Social login** decodes the provider token but doesn't yet verify its
  signature against Apple/Google — **must add before production** (flagged in
  `auth.service.ts`).
- **Seed/demo data** → real data; stop running the seed on production deploys.
- **Free single Render service that sleeps** → autoscaled AWS fleet.
- **JWT logout** is client-side → add a Redis token-revocation list.

None of these touch the app's shape or the API contract, so the mobile app and
admin don't change when we swap them.

## 5. Advice from your developer: don't scale early

Building for millions *before you have thousands* is a classic, expensive
mistake — you burn months and money optimizing traffic that isn't there yet. Our
approach is the professional one:

1. **Now:** clean, portable, standard code on cheap infra. Get real users.
2. **When load grows:** lift-and-shift to AWS (mostly the env-var swaps above).
3. **When it grows more:** turn on the scale layers in §3 one at a time, guided
   by real metrics.

Because we kept it stateless, containerized, config-driven, and contract-first,
each step is an **upgrade, not a rebuild.** That's what protects your time and money.

## 6. Guardrails we keep (so it stays portable)

- Stateless API; no in-memory sessions or local file writes as source of truth.
- All config via environment variables; secrets never in code.
- One database access layer (Prisma) so the DB stays swappable/poolable.
- Integrations (OTP, streaming, MT bridge, storage) sit behind small service
  modules — replace the module, not the app.
- The API contract (`docs/BACKEND_CONTRACT.md`) is the boundary; clients depend
  on it, not on internals.
