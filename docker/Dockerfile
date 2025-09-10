FROM node:18-alpine AS builder

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    ffmpeg \
    sox

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

RUN apk add --no-cache \
    ffmpeg \
    sox \
    curl

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S normaldance -u 1001

# Copy built application
COPY --from=builder --chown=normaldance:nodejs /app/dist ./dist
COPY --from=builder --chown=normaldance:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=normaldance:nodejs /app/package.json ./package.json

# Create storage directories
RUN mkdir -p storage/{uploads,processed,static} && \
    chown -R normaldance:nodejs storage

USER normaldance

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

CMD ["npm", "start"]