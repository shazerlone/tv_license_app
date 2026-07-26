# Millimore backend — production container.
# Multi-stage so the final image is small and holds no build tooling or dev deps.
# Runs anywhere a container runs: AWS ECS/Fargate, EKS, App Runner, Fly, Railway,
# a plain VM. Stateless — run as many replicas as you want behind a load balancer.
#
# Build (from millimore-backend/):   docker build -t millimore-backend .
# Run:                               docker run -p 3000:3000 --env-file .env millimore-backend
#
# NOTE: database migrations are NOT run on container start (an autoscaled fleet
# must not race to migrate). Run them once per deploy as a separate step:
#   npx prisma migrate deploy

# ───────────────────────── build stage ─────────────────────────
FROM node:22-bookworm-slim AS builder
WORKDIR /app

# Backend deps (full, incl. dev) + Prisma client
COPY package*.json ./
RUN npm ci --include=dev
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
COPY scripts ./scripts
RUN npm run build

# Admin static export (served at / by the API for single-origin deploys)
COPY admin/package*.json ./admin/
RUN cd admin && npm ci --include=dev
COPY admin ./admin
RUN cd admin && npm run build

# ───────────────────────── runtime stage ───────────────────────
FROM node:22-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
# Prisma's query engine needs OpenSSL at runtime.
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Production dependencies only
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Compiled app, generated Prisma client/engine, schema, and the admin build
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/admin/out ./admin/out
COPY prisma ./prisma

# Run as the built-in non-root user
USER node

EXPOSE 3000
# Container-native healthcheck hits the same endpoint your load balancer will.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/main.js"]
