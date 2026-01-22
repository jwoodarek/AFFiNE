# =============================================================================
# AFFiNE - Full Build from Source
# =============================================================================
# This builds the entire AFFiNE stack from your forked source code
# Build time: ~15-30 minutes (cached rebuilds are faster)
# =============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build native Rust modules
# ------------------------------------------------------------------------------
FROM rust:1.83-bookworm AS rust-builder

# Install Node.js for napi-rs
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# Install napi-rs CLI globally
RUN npm install -g @napi-rs/cli

WORKDIR /app

# Copy the FULL Cargo workspace (required for workspace dependencies)
COPY Cargo.toml Cargo.lock ./
COPY rust-toolchain.toml ./

# Copy all Rust workspace members
COPY packages/backend/native ./packages/backend/native
COPY packages/common/native ./packages/common/native
COPY packages/common/y-octo ./packages/common/y-octo
COPY packages/frontend/native ./packages/frontend/native
COPY packages/frontend/mobile-native ./packages/frontend/mobile-native

# Build native module for server using napi directly
WORKDIR /app/packages/backend/native
RUN napi build --release --strip

# ------------------------------------------------------------------------------
# Stage 2: Build frontend and backend
# ------------------------------------------------------------------------------
FROM node:22-bookworm AS builder

# Install build tools
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

# Enable corepack for yarn
RUN corepack enable && corepack prepare yarn@4.12.0 --activate

WORKDIR /app

# Copy EVERYTHING first (simpler, more reliable)
COPY . .

# Copy native module from rust builder (overwrite source version)
COPY --from=rust-builder /app/packages/backend/native/server-native.*.node ./packages/backend/native/
COPY --from=rust-builder /app/packages/backend/native/index.js ./packages/backend/native/
COPY --from=rust-builder /app/packages/backend/native/index.d.ts ./packages/backend/native/

# Install all dependencies
RUN yarn install --inline-builds

# Build frontend (web app)
RUN yarn affine @affine/web build

# Build admin panel  
RUN yarn affine @affine/admin build

# Build server
RUN yarn affine @affine/server build

# Generate Prisma client
RUN yarn workspace @affine/server prisma generate

# ------------------------------------------------------------------------------
# Stage 3: Production image
# ------------------------------------------------------------------------------
FROM node:22-bookworm-slim AS runner

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    openssl \
    libjemalloc2 \
    && rm -rf /var/lib/apt/lists/*

# Enable jemalloc for better memory performance
ENV LD_PRELOAD=libjemalloc.so.2

WORKDIR /app

# Copy built server
COPY --from=builder /app/packages/backend/server/dist ./dist
COPY --from=builder /app/packages/backend/server/package.json ./

# Copy static frontend files
COPY --from=builder /app/packages/frontend/apps/web/dist ./static
COPY --from=builder /app/packages/frontend/admin/dist ./static/admin

# Copy Prisma schema and migrations
COPY --from=builder /app/packages/backend/server/prisma ./prisma

# Copy production node_modules  
COPY --from=builder /app/node_modules ./node_modules

# Copy self-host scripts
COPY --from=builder /app/packages/backend/server/scripts ./scripts

# Create storage directories
RUN mkdir -p /root/.affine/storage /root/.affine/config

# Environment
ENV NODE_ENV=production
ENV AFFINE_SERVER_PORT=3010
ENV AFFINE_SERVER_HOST=0.0.0.0

EXPOSE 3010

# Run migrations then start server
CMD ["sh", "-c", "node ./scripts/self-host-predeploy.js && node ./dist/main.js"]
