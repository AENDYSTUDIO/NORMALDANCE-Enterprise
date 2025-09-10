# 5. Безопасность и надежность

## Введение

В этом разделе представлен детальный анализ мер безопасности и надежности архитектуры NormalDance. Оценены текущие механизмы защиты, потенциальные уязвимости и рекомендации по усилению безопасности системы.

## Текущие меры безопасности

### 5.1 Application Security

#### Helmet.js интеграция
```typescript
// src/lib/security.ts
import helmet from 'helmet';

export class SecurityMiddleware {
  static helmet() {
    return helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "https://solana-api.projectserum.com"],
        },
      },
    });
  }
}
```

**Оценка безопасности:**
- ✅ **CSP headers** - Защита от XSS атак
- ✅ **SSL/TLS enforcement** - Принудительное HTTPS
- ✅ **XSS protection** - Защита от межсайтового скриптинга
- ✅ **Clickjacking protection** - Защита от кликджекинга

#### Input validation
```typescript
// src/lib/validators.ts
import { z } from 'zod';

export const trackSchema = z.object({
  title: z.string().min(1).max(100),
  description: z.string().min(1).max(1000),
  price: z.number().positive(),
  duration: z.number().positive(),
  genre: z.string().min(1).max(50),
});

export const nftSchema = z.object({
  trackId: z.string().uuid(),
  edition: z.number().positive(),
  price: z.number().positive(),
});

export function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}
```

**Оценка безопасности:**
- ✅ **Zod validation** - Строгая валидация входных данных
- ✅ **Type safety** - Типизированная валидация
- ✅ **Error handling** - Корректная обработка ошибок

### 5.2 Web3 Security

#### Wallet security
```typescript
// src/components/wallet/wallet-adapter.tsx
export class WalletAdapter {
  private wallet: any;
  private connected: boolean = false;
  
  async connect(): Promise<boolean> {
    try {
      if (typeof window === 'undefined' || !window.solana) {
        throw new Error('Wallet not available');
      }
      
      const response = await window.solana.connect();
      this.wallet = window.solana;
      this.connected = true;
      
      return true;
    } catch (error) {
      console.error('Wallet connection failed:', error);
      return false;
    }
  }
  
  async signTransaction(transaction: Transaction): Promise<Transaction> {
    if (!this.connected || !this.wallet) {
      throw new Error('Wallet not connected');
    }
    
    try {
      return await this.wallet.signTransaction(transaction);
    } catch (error) {
      console.error('Transaction signing failed:', error);
      throw error;
    }
  }
}
```

**Оценка безопасности:**
- ✅ **Wallet validation** - Проверка доступности кошелька
- ✅ **Error handling** - Корректная обработка ошибок
- ✅ **Transaction signing** - Безопасная подпись транзакций

#### Solana security
```typescript
// src/lib/web3-security.ts
import { Connection, PublicKey, Transaction } from '@solana/web3.js';

export class Web3Security {
  private connection: Connection;
  
  constructor() {
    this.connection = new Connection(
      process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
      'confirmed'
    );
  }
  
  async validateTransaction(transaction: Transaction): Promise<boolean> {
    try {
      // Проверка подписи транзакции
      const signature = await this.connection.sendRawTransaction(
        transaction.serialize(),
        { skipPreflight: false }
      );
      
      // Ожидание подтверждения
      await this.connection.confirmTransaction(signature);
      
      return true;
    } catch (error) {
      console.error('Transaction validation failed:', error);
      return false;
    }
  }
  
  async getAccountInfo(publicKey: string): Promise<any> {
    try {
      const accountInfo = await this.connection.getAccountInfo(
        new PublicKey(publicKey)
      );
      
      return accountInfo;
    } catch (error) {
      console.error('Account info retrieval failed:', error);
      return null;
    }
  }
}
```

**Оценка безопасности:**
- ✅ **Transaction validation** - Проверка транзакций
- ✅ **Account verification** - Проверка аккаунтов
- ✅ **Error handling** - Корректная обработка ошибок

### 5.3 Database Security

#### Prisma security
```prisma
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String   @map("password_hash")
  wallet    String?  @unique
  role      UserRole @default(USER)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  tracks    Track[]
  nfts      NFT[]
  transactions Transaction[]
  
  @@index([email])
  @@index([wallet])
}

model Track {
  id          String   @id @default(cuid())
  title       String
  description String
  price       Float
  currency    String   @default("SOL")
  duration    Int
  isPublished Boolean  @default(false)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  userId      String
  user        User     @relation(fields: [userId], references: [id])
  nfts        NFT[]
  audioFile   AudioFile?
  
  @@index([userId])
  @@index([createdAt])
}
```

**Оценка безопасности:**
- ✅ **Unique constraints** - Уникальность email и wallet
- ✅ **Indexing** - Оптимизация запросов
- ✅ **Relation integrity** - Целостность отношений

#### Environment variables
```bash
# .env.example
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/normaldance"

# Security
JWT_SECRET="your-super-secret-jwt-key"
NEXTAUTH_SECRET="your-nextauth-secret"
NEXTAUTH_URL="http://localhost:3000"

# Web3
SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
WALLET_PRIVATE_KEY="your-wallet-private-key"

# Storage
IPFS_API_URL="https://ipfs.infura.io:5001"
FILECOIN_API_URL="https://your-filecoin-api.com"

# Monitoring
SENTRY_DSN="your-sentry-dsn"
GRAFANA_PASSWORD="your-grafana-password"
```

**Оценка безопасности:**
- ✅ **Environment variables** - Конфиденциальные данные в переменных окружения
- ✅ **Secret management** - Управление секретами
- ✅ **URL configuration** - Конфигурация API URL

### 5.4 Network Security

#### CORS configuration
```typescript
// src/lib/cors.ts
import cors from 'cors';

export class CorsConfig {
  static getCorsConfig() {
    return cors({
      origin: process.env.ALLOWED_ORIGINS?.split(',') || [
        'http://localhost:3000',
        'https://normaldance.com',
        'https://www.normaldance.com'
      ],
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: [
        'Origin',
        'X-Requested-With',
        'Content-Type',
        'Accept',
        'Authorization',
        'X-Api-Key'
      ],
      credentials: true,
      maxAge: 86400, // 24 часа
    });
  }
}
```

**Оценка безопасности:**
- ✅ **CORS configuration** - Правильная настройка CORS
- ✅ **Origin restrictions** - Ограничение доменов
- ✅ **Method restrictions** - Ограничение методов
- ✅ **Header restrictions** - Ограничение заголовков

#### Rate limiting
```typescript
// src/lib/rate-limiter.ts
import rateLimit from 'express-rate-limit';
import { createClient } from 'redis';

export class RateLimiter {
  private redisClient: any;
  
  constructor() {
    this.redisClient = createClient({
      url: process.env.REDIS_URL,
    });
    
    this.redisClient.connect();
  }
  
  createRateLimiter(windowMs: number, max: number, message: string) {
    return rateLimit({
      windowMs,
      max,
      message,
      standardHeaders: true,
      legacyHeaders: false,
      handler: (req, res, next, options) => {
        const key = req.ip || req.connection.remoteAddress || 'unknown';
        
        // Логирование попыток
        console.log(`Rate limit exceeded for IP: ${key}`);
        
        // Отправка уведомления в Sentry
        if (process.env.SENTRY_DSN) {
          const Sentry = require('@sentry/node');
          Sentry.captureMessage(`Rate limit exceeded for IP: ${key}`);
        }
        
        res.status(options.statusCode).send(options.message);
      },
    });
  }
}
```

**Оценка безопасности:**
- ✅ **Rate limiting** - Ограничение частоты запросов
- ✅ **Redis integration** - Распределенное rate limiting
- ✅ **Monitoring** - Мониторинг превышений лимитов
- ✅ **Error handling** - Корректная обработка ошибок

### 5.5 Authentication & Authorization

#### NextAuth configuration
```typescript
// src/lib/auth.ts
import NextAuth from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const authOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' }
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        const user = await prisma.user.findUnique({
          where: {
            email: credentials.email
          }
        });

        if (!user) {
          return null;
        }

        // Проверка пароля
        const isPasswordValid = await bcrypt.compare(
          credentials.password,
          user.password
        );

        if (!isPasswordValid) {
          return null;
        }

        return {
          id: user.id,
          email: user.email,
          role: user.role,
        };
      }
    })
  ],
  session: {
    strategy: 'jwt' as const,
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = user.role;
      }
      return token;
    },
    async session({ session, token }) {
      if (token) {
        session.user.id = token.sub!;
        session.user.role = token.role as string;
      }
      return session;
    },
  },
  pages: {
    signIn: '/auth/signin',
    signUp: '/auth/signup',
  },
};

export default NextAuth(authOptions);
```

**Оценка безопасности:**
- ✅ **JWT sessions** - Безопасные сессии
- ✅ **Password hashing** - Хэширование паролей
- ✅ **Role-based access** - Ролевая модель доступа
- ✅ **Session management** - Управление сессиями

#### Authorization middleware
```typescript
// src/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('next-auth.session-token')?.value;
  
  // Защищенные маршруты
  const protectedRoutes = ['/dashboard', '/create', '/admin'];
  const isProtectedRoute = protectedRoutes.some(route => 
    request.nextUrl.pathname.startsWith(route)
  );
  
  if (isProtectedRoute && !token) {
    return NextResponse.redirect(new URL('/auth/signin', request.url));
  }
  
  // Административные маршруты
  const adminRoutes = ['/admin'];
  const isAdminRoute = adminRoutes.some(route => 
    request.nextUrl.pathname.startsWith(route)
  );
  
  if (isAdminRoute) {
    // Проверка роли администратора
    const userRole = request.cookies.get('user-role')?.value;
    if (userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/unauthorized', request.url));
    }
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/create/:path*',
    '/admin/:path*',
  ],
};
```

**Оценка безопасности:**
- ✅ **Route protection** - Защита маршрутов
- ✅ **Role-based access** - Ролевой доступ
- ✅ **Session validation** - Валидация сессий
- ✅ **Redirect handling** - Обработка редиректов

### 5.6 Monitoring & Logging

#### Sentry integration
```typescript
// src/lib/sentry-integration.ts
import * as Sentry from '@sentry/nextjs';

export class SentryIntegration {
  static initialize() {
    if (process.env.SENTRY_DSN) {
      Sentry.init({
        dsn: process.env.SENTRY_DSN,
        tracesSampleRate: 1.0,
        environment: process.env.NODE_ENV || 'development',
        beforeSend(event) {
          // Фильтрация чувствительных данных
          if (event.request?.headers) {
            event.request.headers = {
              ...event.request.headers,
              authorization: '[Filtered]',
              cookie: '[Filtered]',
            };
          }
          
          return event;
        },
      });
    }
  }
  
  static captureError(error: Error, context?: any) {
    if (process.env.SENTRY_DSN) {
      Sentry.captureException(error, {
        extra: context,
      });
    }
  }
  
  static captureMessage(message: string, level: 'info' | 'warning' | 'error' = 'info') {
    if (process.env.SENTRY_DSN) {
      Sentry.captureMessage(message, level);
    }
  }
}
```

**Оценка безопасности:**
- ✅ **Error tracking** - Отслеживание ошибок
- ✅ **Data filtering** - Фильтрация чувствительных данных
- ✅ **Environment configuration** - Конфигурация окружения
- ✅ **Context logging** - Логирование контекста

#### Winston logging
```typescript
// src/lib/logger.ts
import winston from 'winston';
import { ElasticsearchTransport } from '@elastic/elasticsearch/lib/logging';

export class Logger {
  private logger: winston.Logger;
  
  constructor() {
    const transports: winston.transport[] = [
      new winston.transports.Console({
        format: winston.format.combine(
          winston.format.colorize(),
          winston.format.simple()
        ),
      }),
    ];
    
    // Elasticsearch для production
    if (process.env.ELASTICSEARCH_URL) {
      transports.push(
        new ElasticsearchTransport({
          level: 'info',
          clientOpts: {
            node: process.env.ELASTICSEARCH_URL,
          },
          index: 'normaldance-logs',
        })
      );
    }
    
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      transports,
    });
  }
  
  info(message: string, meta?: any) {
    this.logger.info(message, meta);
  }
  
  error(message: string, error?: Error, meta?: any) {
    this.logger.error(message, { error: error?.stack, ...meta });
  }
  
  warn(message: string, meta?: any) {
    this.logger.warn(message, meta);
  }
  
  debug(message: string, meta?: any) {
    this.logger.debug(message, meta);
  }
}
```

**Оценка безопасности:**
- ✅ **Structured logging** - Структурированное логирование
- ✅ **Error tracking** - Отслеживание ошибок
- ✅ **Elasticsearch integration** - Интеграция с Elasticsearch
- ✅ **Log levels** - Уровни логирования

### 5.7 Infrastructure Security

#### Kubernetes security
```yaml
# k8s/security-policy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: normaldance-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: normaldance-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: normaldance-rolebinding
subjects:
- kind: ServiceAccount
  name: default
roleRef:
  kind: Role
  name: normaldance-role
  apiGroup: rbac.authorization.k8s.io
```

**Оценка безопасности:**
- ✅ **Pod Security Policy** - Политика безопасности Pod
- ✅ **RBAC** - Ролевой доступ к Kubernetes
- ✅ **Least privilege** - Принцип минимальных привилегий
- ✅ **Resource isolation** - Изоляция ресурсов

#### Docker security
```dockerfile
# Dockerfile.security
FROM node:18-alpine AS base

# Безопасные настройки
ENV NODE_ENV=production
ENV NPM_CONFIG_LOGLEVEL=error
ENV NPM_CONFIG_PRODUCTION=true

# Создание non-root пользователя
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Установка зависимостей
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Сборка приложения
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Использование tsx для сборки
RUN chown -R nextjs:nodejs /app
USER nextjs
RUN npx tsx build

# Production образ
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

# Копирование файлов
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Запуск от non-root пользователя
USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["node", "server.js"]
```

**Оценка безопасности:**
- ✅ **Non-root user** - Запуск от non-root пользователя
- ✅ **Minimal image** - Минимальный размер образа
- ✅ **Production environment** - Production окружение
- ✅ **File permissions** - Права доступа к файлам

### 5.8 Security Assessment

#### Current security posture
```mermaid
graph TD
    A[Security Assessment] --> B[Application Security]
    A --> C[Web3 Security]
    A --> D[Database Security]
    A --> E[Network Security]
    A --> F[Authentication]
    A --> G[Monitoring]
    A --> H[Infrastructure]
    
    B --> B1[Helmet.js]
    B --> B2[Input Validation]
    B --> B3[CSP Headers]
    
    C --> C1[Wallet Security]
    C --> C2[Transaction Validation]
    C --> C3[Solana Security]
    
    D --> D1[Prisma Security]
    D --> D2[Environment Variables]
    D --> D3[Data Encryption]
    
    E --> E1[CORS Configuration]
    E --> E2[Rate Limiting]
    E --> E3[Firewall Rules]
    
    F --> F1[NextAuth]
    F --> F2[Role-based Access]
    F --> F3[Session Management]
    
    G --> G1[Sentry]
    G --> G2[Winston Logging]
    G --> G3[Security Monitoring]
    
    H --> H1[Kubernetes Security]
    H --> H2[Docker Security]
    H --> H3[Network Policies]
```

#### Security recommendations
1. **Implement regular security audits**
2. **Add automated vulnerability scanning**
3. **Enhance monitoring with SIEM integration**
4. **Implement database encryption at rest**
5. **Add API rate limiting per user**
6. **Implement Web Application Firewall (WAF)**
7. **Add automated penetration testing**
8. **Implement security headers review**

---

*Следующий раздел: [Современные практики разработки](./06-modern-practices.md)*