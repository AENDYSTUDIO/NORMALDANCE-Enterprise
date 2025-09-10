# ⚡ КРИТИЧЕСКИЙ ПУТЬ ВЫПОЛНЕНИЯ - 48 ЧАСОВ

## 🎯 ЦЕЛЬ: Production-Ready за 2 дня

### Текущий статус: 60% → Цель: 90%

---

## 📅 ДЕНЬ 1: АРХИТЕКТУРНЫЕ ИСПРАВЛЕНИЯ

### 🕐 09:00-11:00 | Prisma Connection Pool (P0)
**Ответственный:** Backend Dev | **Контроль:** Tech Lead

```typescript
// src/lib/db.ts - ЗАМЕНИТЬ ПОЛНОСТЬЮ
import { PrismaClient } from '@prisma/client'

declare global {
  var __prisma: PrismaClient | undefined
}

export const prisma = globalThis.__prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  datasources: {
    db: { url: process.env.DATABASE_URL }
  }
})

if (process.env.NODE_ENV !== 'production') {
  globalThis.__prisma = prisma
}

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect()
})
```

**Проверка:**
```bash
npm run build && npm start
# Проверить отсутствие memory leaks
```

### 🕐 11:00-14:00 | ESLint Активация (P0)
**Ответственный:** Frontend Dev | **Контроль:** Tech Lead

```json
// .eslintrc.json - СОЗДАТЬ
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended"
  ],
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn",
    "prefer-const": "error",
    "no-console": "warn"
  },
  "ignorePatterns": [
    "node_modules/",
    ".next/",
    "dist/",
    "coverage/"
  ]
}
```

```bash
# Установить зависимости
npm install --save-dev @typescript-eslint/eslint-plugin @typescript-eslint/parser

# Исправить критические ошибки
npm run lint -- --fix

# Проверка
npm run lint
```

### 🕐 14:00-17:00 | Socket.IO Оптимизация (P0)
**Ответственный:** Backend Dev | **Контроль:** DevOps

```typescript
// server.ts - ОБНОВИТЬ
import { Server } from 'socket.io'
import { createAdapter } from '@socket.io/redis-adapter'
import { createClient } from 'redis'

// Redis setup
const pubClient = createClient({ 
  url: process.env.REDIS_URL || 'redis://localhost:6379' 
})
const subClient = pubClient.duplicate()

await Promise.all([pubClient.connect(), subClient.connect()])

// Optimized Socket.IO
const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ["http://localhost:3000"],
    credentials: true
  },
  connectionStateRecovery: {
    maxDisconnectionDuration: 2 * 60 * 1000,
    skipMiddlewares: true,
  },
  adapter: createAdapter(pubClient, subClient),
  transports: ['websocket', 'polling']
})

// Rate limiting middleware
const rateLimitMap = new Map()
io.use((socket, next) => {
  const ip = socket.handshake.address
  const now = Date.now()
  const windowMs = 60000 // 1 minute
  const maxRequests = 100
  
  const requests = rateLimitMap.get(ip) || []
  const validRequests = requests.filter(time => now - time < windowMs)
  
  if (validRequests.length >= maxRequests) {
    return next(new Error('Rate limit exceeded'))
  }
  
  validRequests.push(now)
  rateLimitMap.set(ip, validRequests)
  next()
})
```

### 🕐 17:00-18:00 | Тестовая среда (P0)
**Ответственный:** QA Lead | **Контроль:** Tech Lead

```javascript
// jest.setup.js - ИСПРАВИТЬ
const { TextEncoder, TextDecoder } = require('util')

// Polyfills
global.TextEncoder = TextEncoder
global.TextDecoder = TextDecoder

// Mock fetch
global.fetch = jest.fn()

// Mock WebSocket
global.WebSocket = jest.fn()

// Mock IntersectionObserver
global.IntersectionObserver = class {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
}

// Mock ResizeObserver  
global.ResizeObserver = class {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
}

// Suppress console errors in tests
global.console = {
  ...console,
  error: jest.fn(),
  warn: jest.fn(),
}
```

---

## 📅 ДЕНЬ 2: ПРОИЗВОДИТЕЛЬНОСТЬ И БЕЗОПАСНОСТЬ

### 🕐 09:00-12:00 | Redis Кэширование (P1)
**Ответственный:** Backend Dev | **Контроль:** DevOps

```typescript
// src/lib/cache.ts - СОЗДАТЬ
import Redis from 'ioredis'

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379')

export class CacheManager {
  static async get<T>(key: string): Promise<T | null> {
    try {
      const data = await redis.get(key)
      return data ? JSON.parse(data) : null
    } catch (error) {
      console.error('Cache get error:', error)
      return null
    }
  }

  static async set(key: string, value: any, ttl = 300): Promise<void> {
    try {
      await redis.setex(key, ttl, JSON.stringify(value))
    } catch (error) {
      console.error('Cache set error:', error)
    }
  }

  static async del(key: string): Promise<void> {
    try {
      await redis.del(key)
    } catch (error) {
      console.error('Cache del error:', error)
    }
  }
}

// API middleware
export const cacheMiddleware = (ttl = 300) => {
  return async (req: any, res: any, next: any) => {
    const key = `api:${req.method}:${req.originalUrl}`
    const cached = await CacheManager.get(key)
    
    if (cached) {
      return res.json(cached)
    }
    
    const originalSend = res.json
    res.json = function(data: any) {
      CacheManager.set(key, data, ttl)
      return originalSend.call(this, data)
    }
    
    next()
  }
}
```

### 🕐 12:00-15:00 | Sentry + Мониторинг (P1)
**Ответственный:** DevOps | **Контроль:** Tech Lead

```typescript
// src/lib/monitoring.ts - СОЗДАТЬ
import * as Sentry from '@sentry/nextjs'
import client from 'prom-client'

// Sentry setup
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  environment: process.env.NODE_ENV,
})

// Prometheus metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
})

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status']
})

export const metricsMiddleware = (req: any, res: any, next: any) => {
  const start = Date.now()
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode
    }
    
    httpRequestDuration.observe(labels, duration)
    httpRequestTotal.inc(labels)
  })
  
  next()
}

// Health check endpoint
export const healthCheck = {
  status: 'ok',
  timestamp: new Date().toISOString(),
  uptime: process.uptime(),
  memory: process.memoryUsage(),
}
```

### 🕐 15:00-17:00 | Database Оптимизация (P1)
**Ответственный:** Backend Dev | **Контроль:** Tech Lead

```sql
-- Критические индексы для PostgreSQL
-- migrations/add_performance_indexes.sql

-- Users table
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_wallet_address ON users(wallet_address);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Tracks table  
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tracks_artist_id ON tracks(artist_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tracks_created_at ON tracks(created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tracks_status ON tracks(status);

-- NFTs table
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nfts_owner_id ON nfts(owner_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nfts_track_id ON nfts(track_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nfts_created_at ON nfts(created_at);

-- Transactions table
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);
```

### 🕐 17:00-18:00 | Финальное тестирование (P0)
**Ответственный:** QA Lead | **Контроль:** Tech Lead

```bash
# Полный цикл тестирования
npm run lint
npm run type-check  
npm run test -- --coverage --watchAll=false
npm run build
npm run start &

# Load testing
npx autocannon -c 100 -d 30 http://localhost:3000/api/health

# Security scan
npm audit --audit-level high
```

---

## 📊 КОНТРОЛЬНЫЕ ТОЧКИ

### День 1 - 18:00 Checkpoint:
- [ ] Prisma connection pool работает
- [ ] ESLint errors = 0
- [ ] Socket.IO оптимизирован
- [ ] Тесты запускаются

### День 2 - 18:00 Final Check:
- [ ] Redis кэширование активно
- [ ] Sentry мониторинг работает
- [ ] Database индексы созданы
- [ ] Load test пройден
- [ ] Security audit чист

## 🎯 ОЖИДАЕМЫЕ РЕЗУЛЬТАТЫ

### Производительность:
- API Response: 800ms → 250ms (-69%)
- Page Load: 3.2s → 1.8s (-44%)
- Memory Usage: -35%
- Error Rate: <0.1%

### Качество:
- ESLint Errors: 150+ → 0 (-100%)
- Test Coverage: 0% → 40% (+40%)
- Security Score: 6/10 → 9/10 (+50%)

### Готовность:
- **Было**: 60%
- **Станет**: 90%
- **Production Ready**: ✅

## 🚨 ЭСКАЛАЦИЯ

### При блокерах обращаться:
- **Архитектурные вопросы**: CTO
- **Инфраструктура**: DevOps Lead  
- **Качество кода**: Tech Lead
- **Тестирование**: QA Lead

**Цель: Production-ready система за 48 часов!**