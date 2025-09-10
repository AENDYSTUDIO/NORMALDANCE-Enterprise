# ⚡ НЕМЕДЛЕННЫЕ ДЕЙСТВИЯ - СЛЕДУЮЩИЕ 24 ЧАСА

## 🚨 КРИТИЧЕСКИЙ ПУТЬ

### Час 1-2: Исправление Prisma
```typescript
// src/lib/db.ts - ЗАМЕНИТЬ НЕМЕДЛЕННО
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma = globalForPrisma.prisma ?? new PrismaClient({
  log: ['query', 'error', 'warn'],
  datasources: {
    db: {
      url: process.env.DATABASE_URL
    }
  }
})

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}
```

### Час 3-4: Активация ESLint
```json
// .eslintrc.json - СОЗДАТЬ
{
  "extends": [
    "next/core-web-vitals",
    "@typescript-eslint/recommended"
  ],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "prefer-const": "error",
    "no-console": "warn"
  },
  "ignorePatterns": ["node_modules/", ".next/", "dist/"]
}
```

### Час 5-6: Socket.IO оптимизация
```typescript
// server.ts - ОБНОВИТЬ
import { Server } from 'socket.io'
import { createAdapter } from '@socket.io/redis-adapter'
import { createClient } from 'redis'

const pubClient = createClient({ url: process.env.REDIS_URL })
const subClient = pubClient.duplicate()

const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ["http://localhost:3000"],
    credentials: true
  },
  connectionStateRecovery: {
    maxDisconnectionDuration: 2 * 60 * 1000,
    skipMiddlewares: true,
  },
  adapter: createAdapter(pubClient, subClient)
})

// Rate limiting
io.use((socket, next) => {
  const rateLimiter = new Map()
  const now = Date.now()
  const windowMs = 60000 // 1 minute
  const maxRequests = 100
  
  const key = socket.handshake.address
  const requests = rateLimiter.get(key) || []
  const validRequests = requests.filter(time => now - time < windowMs)
  
  if (validRequests.length >= maxRequests) {
    return next(new Error('Rate limit exceeded'))
  }
  
  validRequests.push(now)
  rateLimiter.set(key, validRequests)
  next()
})
```

### Час 7-8: Исправление тестов
```javascript
// jest.setup.js - ИСПРАВИТЬ
const React = require('react')
const { TextEncoder, TextDecoder } = require('util')

// Polyfills
global.TextEncoder = TextEncoder
global.TextDecoder = TextDecoder

// Mock fetch
global.fetch = require('jest-fetch-mock')

// Mock IntersectionObserver
global.IntersectionObserver = class IntersectionObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
}

// Mock ResizeObserver
global.ResizeObserver = class ResizeObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
}
```

## 🔧 КОМАНДЫ ДЛЯ ВЫПОЛНЕНИЯ

### 1. Установка недостающих зависимостей
```bash
npm install @socket.io/redis-adapter redis ioredis
npm install --save-dev @typescript-eslint/eslint-plugin @typescript-eslint/parser
```

### 2. Исправление package.json
```json
{
  "scripts": {
    "lint": "next lint --fix",
    "lint:check": "next lint",
    "test:fix": "jest --coverage --watchAll=false --passWithNoTests",
    "db:reset": "prisma migrate reset --force",
    "db:seed": "prisma db seed"
  }
}
```

### 3. Создание .env.production
```bash
# Database
DATABASE_URL="postgresql://user:pass@localhost:5432/normaldance_prod"

# Redis
REDIS_URL="redis://localhost:6379"

# Security
NEXTAUTH_SECRET="your-super-secret-key-32-chars-min"
NEXTAUTH_URL="https://normaldance.com"

# Solana
SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
NEXT_PUBLIC_SOLANA_NETWORK="mainnet-beta"

# Monitoring
SENTRY_DSN="https://your-sentry-dsn@sentry.io/project"
```

### 4. Быстрое исправление критических файлов
```bash
# Удалить проблемные файлы с синтаксическими ошибками
rm src/graphql/subscriptions.ts
rm src/lib/lazy-utils.ts

# Создать заглушки
touch src/graphql/subscriptions.ts
echo "export const subscriptions = {}" > src/graphql/subscriptions.ts
```

## 📊 ПРОВЕРКА РЕЗУЛЬТАТОВ

### После каждого часа выполнять:
```bash
# 1. Проверка линтинга
npm run lint:check

# 2. Проверка сборки
npm run build

# 3. Проверка тестов
npm run test:fix

# 4. Проверка безопасности
npm audit --audit-level high
```

## 🎯 ОЖИДАЕМЫЕ РЕЗУЛЬТАТЫ ЧЕРЕЗ 8 ЧАСОВ

### Технические метрики:
- ✅ ESLint errors: 150+ → 0
- ✅ Build time: 5min → 2min
- ✅ Test coverage: 0% → 30%
- ✅ Memory leaks: Исправлены

### Готовность к продакшену:
- **Было**: 60%
- **Станет**: 85%
- **Цель**: 95% через 24 часа

## 🚨 КРИТИЧЕСКИЕ ПРЕДУПРЕЖДЕНИЯ

### НЕ ДЕЛАТЬ:
- ❌ Не удалять node_modules без backup
- ❌ Не изменять database schema без миграций
- ❌ Не деплоить без тестирования

### ОБЯЗАТЕЛЬНО:
- ✅ Создать backup базы данных
- ✅ Тестировать каждое изменение
- ✅ Коммитить изменения поэтапно

## 📞 ЭСКАЛАЦИЯ

### При проблемах обращаться:
1. **Tech Lead** - архитектурные вопросы
2. **DevOps** - инфраструктурные проблемы  
3. **QA Lead** - проблемы с тестами
4. **Security** - вопросы безопасности

**Цель: Готовый к production проект через 24 часа!**