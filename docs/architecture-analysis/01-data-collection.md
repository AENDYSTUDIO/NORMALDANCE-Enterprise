# 1. Сбор и анализ исходных данных

## Введение

В этом разделе представлен детальный анализ ключевых файлов проекта NormalDance, который послужил основой для полного архитектурного анализа. Изучены все основные компоненты системы, включая конфигурационные файлы, зависимости, схемы баз данных и инфраструктурные настройки.

## Ключевые файлы проекта

### 1.1 Package.json

**Основные метаданные:**
- Название: `normaldance-platform`
- Версия: `1.0.0`
- Описание: "NORMALDANCE - Музыкальная платформа с блокчейн интеграцией"

**Ключевые зависимости:**

#### Frontend стек:
```json
{
  "next": "^14.0.0",
  "react": "^18.2.0",
  "react-dom": "^18.2.0",
  "typescript": "^5.2.2",
  "tailwindcss": "^3.3.6"
}
```

#### Web3 интеграция:
```json
{
  "@solana/wallet-adapter-react": "^0.15.35",
  "@solana/wallet-adapter-wallets": "^0.19.26",
  "@solana/web3.js": "^1.87.6"
}
```

#### Backend и инфраструктура:
```json
{
  "prisma": "^5.6.0",
  "@prisma/client": "^5.6.0",
  "socket.io": "^4.7.2",
  "express": "^4.18.2",
  "next-auth": "^4.24.5"
}
```

#### Система мониторинга:
```json
{
  "@sentry/nextjs": "^10.11.0",
  "winston": "^3.11.0"
}
```

**Скрипты сборки:**
```json
{
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "test": "jest",
  "db:migrate": "prisma migrate dev",
  "deploy:prod": "docker-compose -f configs/docker/docker-compose.prod.yml up -d"
}
```

### 1.2 Next.js конфигурация

**Основные настройки оптимизации:**
- `reactStrictMode: true` - строгий режим React
- `swcMinify: true` - оптимизация сборки
- `output: 'standalone'` - standalone сборка для Docker

**Оптимизация изображений:**
```typescript
images: {
  formats: ['image/webp', 'image/avif'],
  deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
  imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
  minimumCacheTTL: 31536000 // 1 год
}
```

**Критические настройки:**
- ESLint отключен: `ignoreDuringBuilds: true`
- TypeScript проверки отключены: `ignoreBuildErrors: true`
- Socket.IO реврайт: `/socket.io` → `/api/socketio`

### 1.3 Prisma схема базы данных

**Основные сущности:**

```prisma
model User {
  id          String   @id @default(cuid())
  email       String   @unique
  name        String?
  wallet      String?
  role        UserRole @default(USER)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  // Связи
  tracks      Track[]
  playlists   Playlist[]
  nfts        NFT[]
  transactions Transaction[]
}

model Track {
  id          String   @id @default(cuid())
  title       String
  description String?
  duration    Int
  price       Float
  currency    String   @default("SOL")
  isPublished Boolean  @default(false)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  // Связи
  userId      String
  user        User     @relation(fields: [userId], references: [id])
  nfts        NFT[]
  audioFile   AudioFile?
}

model NFT {
  id          String   @id @default(cuid())
  tokenId     String   @unique
  metadata    String   // JSON metadata
  price       Float
  currency    String   @default("SOL")
  isListed    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  // Связи
  userId      String
  user        User     @relation(fields: [userId], references: [id])
  trackId     String
  track       Track    @relation(fields: [trackId], references: [id])
}

model AudioFile {
  id          String   @id @default(cuid())
  filename    String
  mimetype    String
  size        Int
  duration    Int?
  ipfsHash    String
  filecoinCid String?
  createdAt   DateTime @default(now())
  
  // Связи
  trackId     String   @unique
  track       Track    @relation(fields: [trackId], references: [id])
}

model Transaction {
  id          String   @id @default(cuid())
  type        TransactionType
  amount      Float
  currency    String   @default("SOL")
  status      TransactionStatus @default(PENDING)
  txHash      String?
  blockNumber Int?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  // Связи
  userId      String
  user        User     @relation(fields: [userId], references: [id])
  nftId       String?
  nft         NFT?     @relation(fields: [nftId], references: [id])
}
```

### 1.4 CI/CD конфигурация

**GitHub Actions workflow:**

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x, 20.x]
    
    steps:
    - uses: actions/checkout@v3
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm test
    
    - name: Build application
      run: npm run build
    
    - name: Security audit
      run: npm audit --audit-level high

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to production
      run: |
        echo "Deploying to production..."
        # Deployment logic here
```

### 1.5 Docker конфигурация

**Production Docker Compose:**

```yaml
version: '3.8'

services:
  # Основное приложение
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile.prod
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  # PostgreSQL база данных
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  # Redis кэш
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  # WebSocket сервис
  websocket:
    build:
      context: .
      dockerfile: docker/Dockerfile.websocket
    ports:
      - "3001:3001"
    depends_on:
      - redis
    restart: unless-stopped

  # API сервис
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    ports:
      - "3002:3002"
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### 1.6 Kubernetes конфигурация

**Helm чарты:**

```yaml
# values.yaml
global:
  imageRegistry: "normaldance.azurecr.io"
  imageTag: "latest"

app:
  replicaCount: 3
  image:
    repository: "normaldance-platform"
    pullPolicy: "Always"
  service:
    type: "LoadBalancer"
    port: 80
    targetPort: 3000
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

database:
  enabled: true
  postgresql:
    global:
      postgresql:
        auth:
          postgresPassword: "secure-password"
    primary:
      persistence:
        enabled: true
        size: 10Gi
```

### 1.7 Кастомные архитектурные файлы

#### Server.ts
```typescript
import { createServer } from 'http';
import { Server } from 'socket.io';
import next from 'next';

const dev = process.env.NODE_ENV !== 'production';
const hostname = 'localhost';
const port = 3000;

const app = next({ dev, hostname, port });
const handler = app.getRequestHandler();

const server = createServer(async (req, res) => {
  await handler(req, res);
});

const io = new Server(server, {
  path: '/api/socketio',
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

server.listen(port, () => {
  console.log(`> Ready on http://${hostname}:${port}`);
});
```

#### Wallet Adapter
```typescript
import { EventEmitter } from 'events';

export class WalletAdapter extends EventEmitter {
  private wallet: any;
  private connected: boolean = false;
  
  constructor() {
    super();
    this.setupWallet();
  }
  
  private setupWallet() {
    // Кастомная логика подключения к Phantom кошельку
  }
  
  async connect(): Promise<boolean> {
    try {
      // Логика подключения
      this.connected = true;
      this.emit('connected');
      return true;
    } catch (error) {
      // Silent failure - возвращаем 0 вместо ошибки
      return false;
    }
  }
  
  async disconnect(): Promise<void> {
    this.connected = false;
    this.emit('disconnected');
  }
  
  async signTransaction(transaction: any): Promise<any> {
    try {
      // Логика подписи транзакции
      return transaction;
    } catch (error) {
      // Silent failure
      return 0;
    }
  }
}
```

#### Deflationary Model
```typescript
export class DeflationaryModel {
  private static BURN_RATE = 0.02; // 2%
  
  static calculateBurn(amount: number): number {
    return amount * this.BURN_RATE;
  }
  
  static calculateNetAmount(amount: number): number {
    const burn = this.calculateBurn(amount);
    return amount - burn;
  }
  
  static calculateTotalSupply(
    currentSupply: number, 
    transactionAmount: number
  ): number {
    const netAmount = this.calculateNetAmount(transactionAmount);
    return currentSupply + netAmount;
  }
}
```

## Выводы по сбору данных

### 1.8 Архитектурные паттерны, выявленные из файлов

#### Кастомные решения:
1. **Custom server setup** - Используется `server.ts` с Socket.IO вместо стандартного Next.js сервера
2. **Wallet integration** - Кастомный event emitter system для Phantom кошелька
3. **Deflationary model** - 2% burn на всех транзакциях
4. **Database** - Global Prisma instance в `src/lib/db.ts`
5. **Error handling** - Wallet operations возвращают 0 вместо ошибок (silent failures)

#### Технологический стек:
- **Frontend**: Next.js 14, React 18, TypeScript, TailwindCSS
- **Backend**: Custom server, Socket.IO, GraphQL
- **Database**: PostgreSQL с Prisma ORM
- **Web3**: Solana, Phantom wallet, SPL tokens
- **Infrastructure**: Docker, Kubernetes, Helm
- **Monitoring**: Prometheus, Grafana, ELK Stack

#### Критические настройки:
- ESLint отключен для ускорения сборки
- TypeScript имеет relaxed настройки для Web3 кода
- Используется `tsx` напрямую для production builds
- Next.js build отключен в пользу кастомного процесса

---

*Следующий раздел: [Анализ архитектурных паттернов](./02-architectural-patterns.md)*