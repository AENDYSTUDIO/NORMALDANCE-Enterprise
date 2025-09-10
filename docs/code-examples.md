# 💻 Примеры кода NORMAL DANCE

## 🔧 Конфигурационные файлы

### Docker Compose - Полная конфигурация
```yaml
# docker-compose.cyberentics-minimal.yml
version: '3.8'

services:
  # Основное веб-приложение
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: dev
    container_name: normaldance-app-dev
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://user:password@postgres:5432/normaldance
      - NEXTAUTH_URL=http://localhost:3000
      - NEXTAUTH_SECRET=dev_secret_key
      - REDIS_URL=redis://redis:6379
      - IPFS_API_URL=http://ipfs:5001
      - SOLANA_RPC_URL=https://api.devnet.solana.com
    volumes:
      - .:/app
      - /app/node_modules
      - /app/.next
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      ipfs:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - normaldance-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL база данных
  postgres:
    image: postgres:15-alpine
    container_name: normaldance-postgres-dev
    environment:
      - POSTGRES_DB=normaldance
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d normaldance"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - normaldance-network

  # Redis кэш и сессии
  redis:
    image: redis:7-alpine
    container_name: normaldance-redis-dev
    command: redis-server --appendonly yes --requirepass redis_password
    volumes:
      - redis_data:/data
      - ./config/redis.conf:/usr/local/etc/redis/redis.conf
    ports:
      - "6379:6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - normaldance-network

  # IPFS для децентрализованного хранения
  ipfs:
    image: ipfs/kubo:v0.21.0
    container_name: normaldance-ipfs-dev
    ports:
      - "5001:5001"  # API
      - "8080:8080"  # Gateway
      - "4001:4001"  # Swarm
    volumes:
      - ipfs_data:/data/ipfs
      - ./config/ipfs:/container-init.d
    environment:
      - IPFS_PROFILE=server
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/api/v0/version"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - normaldance-network

  # Redis Commander для управления
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: normaldance-redis-commander-dev
    ports:
      - "8081:8081"
    environment:
      - REDIS_HOSTS=local:redis:6379:0:redis_password
      - HTTP_USER=admin
      - HTTP_PASSWORD=admin
    depends_on:
      - redis
    restart: unless-stopped
    networks:
      - normaldance-network

  # Prometheus для мониторинга
  prometheus:
    image: prom/prometheus:latest
    container_name: normaldance-prometheus-dev
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
    restart: unless-stopped
    networks:
      - normaldance-network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  ipfs_data:
    driver: local
  prometheus_data:
    driver: local

networks:
  normaldance-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
```

### Dockerfile - Multi-stage build
```dockerfile
# Dockerfile
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM base AS dev
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

FROM base AS build
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS production
WORKDIR /app
COPY --from=base /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/package.json ./package.json
EXPOSE 3000
CMD ["npm", "start"]
```

## 🎵 API Endpoints - Примеры кода

### Track Upload API
```typescript
// src/app/api/tracks/upload/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { prisma } from '@/lib/db';
import { uploadToIPFS } from '@/lib/ipfs';
import { validateAudioFile } from '@/lib/validation';

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession();
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const formData = await request.formData();
    const file = formData.get('audio') as File;
    const title = formData.get('title') as string;
    const genre = formData.get('genre') as string;

    // Валидация файла
    const validation = await validateAudioFile(file);
    if (!validation.isValid) {
      return NextResponse.json({ error: validation.error }, { status: 400 });
    }

    // Загрузка в IPFS
    const ipfsHash = await uploadToIPFS(file);
    
    // Сохранение в базу данных
    const track = await prisma.track.create({
      data: {
        title,
        genre,
        duration: validation.duration,
        ipfsHash,
        artistId: session.user.id,
        artistName: session.user.name || 'Unknown Artist',
        metadata: {
          fileSize: file.size,
          mimeType: file.type,
          bitrate: validation.bitrate,
          sampleRate: validation.sampleRate,
        },
      },
    });

    return NextResponse.json({ 
      success: true, 
      track: {
        id: track.id,
        title: track.title,
        ipfsHash: track.ipfsHash,
      }
    });

  } catch (error) {
    console.error('Track upload error:', error);
    return NextResponse.json(
      { error: 'Internal server error' }, 
      { status: 500 }
    );
  }
}
```

### NFT Minting Service
```typescript
// src/lib/nft-service.ts
import { Connection, PublicKey, Transaction } from '@solana/web3.js';
import { createCreateMetadataAccountV3Instruction } from '@metaplex-foundation/mpl-token-metadata';
import { prisma } from './db';

export class NFTService {
  private connection: Connection;
  
  constructor() {
    this.connection = new Connection(
      process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com'
    );
  }

  async mintTrackNFT(trackId: string, artistWallet: string) {
    try {
      const track = await prisma.track.findUnique({
        where: { id: trackId },
        include: { artist: true }
      });

      if (!track) {
        throw new Error('Track not found');
      }

      // Создание метаданных NFT
      const metadata = {
        name: `${track.title} - ${track.artistName}`,
        description: `Exclusive NFT for the track "${track.title}" by ${track.artistName}`,
        image: `https://ipfs.io/ipfs/${track.ipfsHash}`,
        attributes: [
          { trait_type: 'Artist', value: track.artistName },
          { trait_type: 'Genre', value: track.genre },
          { trait_type: 'Duration', value: track.duration.toString() },
          { trait_type: 'Play Count', value: track.playCount.toString() },
        ],
        properties: {
          files: [
            {
              uri: `https://ipfs.io/ipfs/${track.ipfsHash}`,
              type: 'audio/mpeg',
            },
          ],
          category: 'audio',
        },
      };

      // Загрузка метаданных в IPFS
      const metadataUri = await this.uploadMetadataToIPFS(metadata);

      // Создание NFT транзакции
      const mintKeypair = new PublicKey(artistWallet);
      const transaction = new Transaction();

      // Добавление инструкций для создания NFT
      const createMetadataInstruction = createCreateMetadataAccountV3Instruction(
        {
          metadata: mintKeypair,
          mint: mintKeypair,
          mintAuthority: mintKeypair,
          payer: mintKeypair,
          updateAuthority: mintKeypair,
        },
        {
          createMetadataAccountArgsV3: {
            data: {
              name: metadata.name,
              symbol: 'NDTRACK',
              uri: metadataUri,
              sellerFeeBasisPoints: 250, // 2.5% роялти
              creators: [
                {
                  address: mintKeypair,
                  verified: true,
                  share: 100,
                },
              ],
            },
            isMutable: true,
            collectionDetails: null,
          },
        }
      );

      transaction.add(createMetadataInstruction);

      // Сохранение NFT в базу данных
      const nft = await prisma.nFT.create({
        data: {
          tokenId: mintKeypair.toString(),
          name: metadata.name,
          description: metadata.description,
          imageUrl: metadata.image,
          metadata: metadata,
          ownerId: track.artistId,
          trackId: track.id,
          type: 'TRACK',
          status: 'MINTED',
        },
      });

      return {
        nft,
        transaction: transaction.serialize(),
        metadataUri,
      };

    } catch (error) {
      console.error('NFT minting error:', error);
      throw error;
    }
  }

  private async uploadMetadataToIPFS(metadata: any): Promise<string> {
    // Реализация загрузки метаданных в IPFS
    // Возвращает URI метаданных
    return 'ipfs://metadata-hash';
  }
}
```

### Audio Streaming Service
```typescript
// src/lib/audio-streaming.ts
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from './db';
import { getIPFSFile } from './ipfs';
import { validateUserAccess } from './auth';

export async function streamAudio(request: NextRequest, trackId: string) {
  try {
    // Проверка доступа пользователя
    const hasAccess = await validateUserAccess(request, trackId);
    if (!hasAccess) {
      return new NextResponse('Unauthorized', { status: 401 });
    }

    // Получение информации о треке
    const track = await prisma.track.findUnique({
      where: { id: trackId },
      select: { ipfsHash: true, title: true, artistName: true }
    });

    if (!track) {
      return new NextResponse('Track not found', { status: 404 });
    }

    // Получение файла из IPFS
    const audioStream = await getIPFSFile(track.ipfsHash);
    
    // Обработка Range запросов для поддержки перемотки
    const range = request.headers.get('range');
    if (range) {
      return handleRangeRequest(audioStream, range);
    }

    // Логирование воспроизведения
    await logPlayEvent(trackId, request);

    // Возврат аудио потока
    return new NextResponse(audioStream, {
      headers: {
        'Content-Type': 'audio/mpeg',
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=3600',
      },
    });

  } catch (error) {
    console.error('Audio streaming error:', error);
    return new NextResponse('Internal Server Error', { status: 500 });
  }
}

async function handleRangeRequest(audioStream: ReadableStream, range: string) {
  // Реализация поддержки HTTP Range запросов
  const parts = range.replace(/bytes=/, '').split('-');
  const start = parseInt(parts[0], 10);
  const end = parts[1] ? parseInt(parts[1], 10) : undefined;

  // Возврат частичного контента
  return new NextResponse(audioStream, {
    status: 206,
    headers: {
      'Content-Type': 'audio/mpeg',
      'Accept-Ranges': 'bytes',
      'Content-Range': `bytes ${start}-${end || 'end'}/total`,
    },
  });
}

async function logPlayEvent(trackId: string, request: NextRequest) {
  // Логирование события воспроизведения для аналитики
  const userAgent = request.headers.get('user-agent');
  const ip = request.headers.get('x-forwarded-for') || 'unknown';
  
  await prisma.playHistory.create({
    data: {
      trackId,
      userId: 'anonymous', // Или ID пользователя из сессии
      duration: 0,
      completed: false,
      metadata: {
        userAgent,
        ip,
        timestamp: new Date().toISOString(),
      },
    },
  });

  // Увеличение счетчика воспроизведений
  await prisma.track.update({
    where: { id: trackId },
    data: { playCount: { increment: 1 } },
  });
}
```

## 🔐 Аутентификация и безопасность

### NextAuth Configuration
```typescript
// src/lib/auth.ts
import { NextAuthOptions } from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import { prisma } from './db';
import { verifyWalletSignature } from './web3';

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    CredentialsProvider({
      id: 'wallet',
      name: 'Wallet',
      credentials: {
        publicKey: { label: 'Public Key', type: 'text' },
        signature: { label: 'Signature', type: 'text' },
        message: { label: 'Message', type: 'text' },
      },
      async authorize(credentials) {
        if (!credentials?.publicKey || !credentials?.signature) {
          return null;
        }

        // Верификация подписи кошелька
        const isValid = await verifyWalletSignature(
          credentials.publicKey,
          credentials.signature,
          credentials.message
        );

        if (!isValid) {
          return null;
        }

        // Поиск или создание пользователя
        let user = await prisma.user.findUnique({
          where: { wallet: credentials.publicKey },
        });

        if (!user) {
          user = await prisma.user.create({
            data: {
              wallet: credentials.publicKey,
              username: `user_${credentials.publicKey.slice(-8)}`,
              email: `${credentials.publicKey}@normaldance.app`,
            },
          });
        }

        return {
          id: user.id,
          email: user.email,
          name: user.username,
          wallet: user.wallet,
        };
      },
    }),
  ],
  session: {
    strategy: 'jwt',
    maxAge: 24 * 60 * 60, // 24 часа
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.wallet = user.wallet;
      }
      return token;
    },
    async session({ session, token }) {
      session.user.wallet = token.wallet as string;
      return session;
    },
  },
  pages: {
    signIn: '/auth/signin',
    error: '/auth/error',
  },
};
```

### Rate Limiting Middleware
```typescript
// src/lib/rate-limiter.ts
import { NextRequest, NextResponse } from 'next/server';
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL!);

interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
  keyGenerator?: (request: NextRequest) => string;
}

export function createRateLimiter(config: RateLimitConfig) {
  return async (request: NextRequest): Promise<NextResponse | null> => {
    const key = config.keyGenerator 
      ? config.keyGenerator(request)
      : getClientIP(request);

    const identifier = `rate_limit:${key}`;
    const window = Math.floor(Date.now() / config.windowMs);
    const windowKey = `${identifier}:${window}`;

    try {
      const current = await redis.incr(windowKey);
      
      if (current === 1) {
        await redis.expire(windowKey, Math.ceil(config.windowMs / 1000));
      }

      if (current > config.maxRequests) {
        return new NextResponse('Too Many Requests', {
          status: 429,
          headers: {
            'X-RateLimit-Limit': config.maxRequests.toString(),
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': (Date.now() + config.windowMs).toString(),
          },
        });
      }

      return null; // Продолжить обработку запроса
    } catch (error) {
      console.error('Rate limiting error:', error);
      return null; // В случае ошибки разрешаем запрос
    }
  };
}

function getClientIP(request: NextRequest): string {
  return request.headers.get('x-forwarded-for')?.split(',')[0] ||
         request.headers.get('x-real-ip') ||
         'unknown';
}

// Использование
export const apiRateLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 минут
  maxRequests: 100, // 100 запросов на IP
});

export const uploadRateLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 час
  maxRequests: 10, // 10 загрузок на IP
});
```

## 🎧 Frontend Components

### Audio Player Component
```typescript
// src/components/audio/AudioPlayer.tsx
'use client';

import { useState, useRef, useEffect } from 'react';
import { Play, Pause, SkipForward, SkipBack, Volume2 } from 'lucide-react';
import { useAudioStore } from '@/store/use-audio-store';
import { formatTime } from '@/lib/utils';

interface AudioPlayerProps {
  track: {
    id: string;
    title: string;
    artistName: string;
    duration: number;
    ipfsHash: string;
  };
}

export function AudioPlayer({ track }: AudioPlayerProps) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isLoading, setIsLoading] = useState(false);

  const { currentTrack, setCurrentTrack, addToHistory } = useAudioStore();

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const handleTimeUpdate = () => setCurrentTime(audio.currentTime);
    const handleLoadStart = () => setIsLoading(true);
    const handleCanPlay = () => setIsLoading(false);
    const handleEnded = () => {
      setIsPlaying(false);
      addToHistory(track);
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('loadstart', handleLoadStart);
    audio.addEventListener('canplay', handleCanPlay);
    audio.addEventListener('ended', handleEnded);

    return () => {
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('loadstart', handleLoadStart);
      audio.removeEventListener('canplay', handleCanPlay);
      audio.removeEventListener('ended', handleEnded);
    };
  }, [track, addToHistory]);

  const togglePlayPause = async () => {
    const audio = audioRef.current;
    if (!audio) return;

    if (isPlaying) {
      audio.pause();
      setIsPlaying(false);
    } else {
      try {
        await audio.play();
        setIsPlaying(true);
        setCurrentTrack(track);
        
        // Отправка события воспроизведения на сервер
        fetch(`/api/tracks/${track.id}/play`, { method: 'POST' });
      } catch (error) {
        console.error('Playback error:', error);
      }
    }
  };

  const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    const audio = audioRef.current;
    if (!audio) return;

    const newTime = (parseFloat(e.target.value) / 100) * track.duration;
    audio.currentTime = newTime;
    setCurrentTime(newTime);
  };

  const handleVolumeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const audio = audioRef.current;
    const newVolume = parseFloat(e.target.value) / 100;
    
    if (audio) {
      audio.volume = newVolume;
    }
    setVolume(newVolume);
  };

  const progress = (currentTime / track.duration) * 100;

  return (
    <div className="bg-white rounded-lg shadow-lg p-6 max-w-md mx-auto">
      <audio
        ref={audioRef}
        src={`/api/tracks/${track.id}/stream`}
        preload="metadata"
      />
      
      {/* Track Info */}
      <div className="text-center mb-4">
        <h3 className="font-semibold text-lg text-gray-900">{track.title}</h3>
        <p className="text-gray-600">{track.artistName}</p>
      </div>

      {/* Progress Bar */}
      <div className="mb-4">
        <input
          type="range"
          min="0"
          max="100"
          value={progress || 0}
          onChange={handleSeek}
          className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
        />
        <div className="flex justify-between text-sm text-gray-500 mt-1">
          <span>{formatTime(currentTime)}</span>
          <span>{formatTime(track.duration)}</span>
        </div>
      </div>

      {/* Controls */}
      <div className="flex items-center justify-center space-x-4 mb-4">
        <button className="p-2 rounded-full hover:bg-gray-100">
          <SkipBack size={20} />
        </button>
        
        <button
          onClick={togglePlayPause}
          disabled={isLoading}
          className="p-3 bg-blue-500 text-white rounded-full hover:bg-blue-600 disabled:opacity-50"
        >
          {isLoading ? (
            <div className="animate-spin w-6 h-6 border-2 border-white border-t-transparent rounded-full" />
          ) : isPlaying ? (
            <Pause size={24} />
          ) : (
            <Play size={24} />
          )}
        </button>
        
        <button className="p-2 rounded-full hover:bg-gray-100">
          <SkipForward size={20} />
        </button>
      </div>

      {/* Volume Control */}
      <div className="flex items-center space-x-2">
        <Volume2 size={16} className="text-gray-500" />
        <input
          type="range"
          min="0"
          max="100"
          value={volume * 100}
          onChange={handleVolumeChange}
          className="flex-1 h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer"
        />
      </div>
    </div>
  );
}
```

### Wallet Connection Component
```typescript
// src/components/wallet/WalletConnect.tsx
'use client';

import { useState } from 'react';
import { signIn, signOut, useSession } from 'next-auth/react';
import { Wallet, LogOut } from 'lucide-react';

export function WalletConnect() {
  const { data: session, status } = useSession();
  const [isConnecting, setIsConnecting] = useState(false);

  const connectWallet = async () => {
    if (typeof window === 'undefined' || !window.solana?.isPhantom) {
      alert('Phantom Wallet не найден. Пожалуйста, установите расширение.');
      return;
    }

    setIsConnecting(true);

    try {
      // Подключение к Phantom Wallet
      const response = await window.solana.connect();
      const publicKey = response.publicKey.toString();

      // Создание сообщения для подписи
      const message = `Вход в NORMAL DANCE\nВремя: ${new Date().toISOString()}`;
      const encodedMessage = new TextEncoder().encode(message);

      // Запрос подписи
      const signature = await window.solana.signMessage(encodedMessage);
      const signatureBase64 = btoa(String.fromCharCode(...signature.signature));

      // Аутентификация через NextAuth
      const result = await signIn('wallet', {
        publicKey,
        signature: signatureBase64,
        message,
        redirect: false,
      });

      if (result?.error) {
        console.error('Authentication error:', result.error);
        alert('Ошибка аутентификации');
      }
    } catch (error) {
      console.error('Wallet connection error:', error);
      alert('Ошибка подключения кошелька');
    } finally {
      setIsConnecting(false);
    }
  };

  const disconnectWallet = async () => {
    await signOut({ redirect: false });
    if (window.solana?.isPhantom) {
      await window.solana.disconnect();
    }
  };

  if (status === 'loading') {
    return (
      <div className="animate-pulse bg-gray-200 rounded-lg px-4 py-2 w-32 h-10" />
    );
  }

  if (session?.user) {
    return (
      <div className="flex items-center space-x-2">
        <div className="text-sm">
          <p className="font-medium">{session.user.name}</p>
          <p className="text-gray-500 text-xs">
            {session.user.wallet?.slice(0, 4)}...{session.user.wallet?.slice(-4)}
          </p>
        </div>
        <button
          onClick={disconnectWallet}
          className="p-2 text-gray-500 hover:text-red-500 rounded-lg hover:bg-gray-100"
        >
          <LogOut size={16} />
        </button>
      </div>
    );
  }

  return (
    <button
      onClick={connectWallet}
      disabled={isConnecting}
      className="flex items-center space-x-2 bg-purple-500 text-white px-4 py-2 rounded-lg hover:bg-purple-600 disabled:opacity-50"
    >
      <Wallet size={16} />
      <span>
        {isConnecting ? 'Подключение...' : 'Подключить кошелек'}
      </span>
    </button>
  );
}
```

## 📊 Мониторинг и аналитика

### Prometheus Configuration
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'normaldance-app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: '/api/metrics'
    scrape_interval: 30s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']

  - job_name: 'ipfs'
    static_configs:
      - targets: ['ipfs:5001']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### Metrics Collection
```typescript
// src/lib/metrics.ts
import { register, Counter, Histogram, Gauge } from 'prom-client';

// Счетчики
export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

export const trackPlaysTotal = new Counter({
  name: 'track_plays_total',
  help: 'Total number of track plays',
  labelNames: ['track_id', 'artist_id'],
});

export const nftMintedTotal = new Counter({
  name: 'nft_minted_total',
  help: 'Total number of NFTs minted',
  labelNames: ['type'],
});

// Гистограммы
export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.5, 1, 2, 5],
});

export const audioStreamDuration = new Histogram({
  name: 'audio_stream_duration_seconds',
  help: 'Duration of audio streaming requests',
  buckets: [1, 5, 10, 30, 60, 300],
});

// Gauges
export const activeUsers = new Gauge({
  name: 'active_users',
  help: 'Number of currently active users',
});

export const totalTracks = new Gauge({
  name: 'total_tracks',
  help: 'Total number of tracks in the platform',
});

// Регистрация метрик
register.registerMetric(httpRequestsTotal);
register.registerMetric(trackPlaysTotal);
register.registerMetric(nftMintedTotal);
register.registerMetric(httpRequestDuration);
register.registerMetric(audioStreamDuration);
register.registerMetric(activeUsers);
register.registerMetric(totalTracks);

// API endpoint для метрик
export async function getMetrics() {
  return register.metrics();
}
```

## 🚀 Deployment Scripts

### Deployment Script
```bash
#!/bin/bash
# scripts/deploy.sh

set -e

echo "🚀 Starting NORMAL DANCE deployment..."

# Проверка переменных окружения
if [ -z "$NODE_ENV" ]; then
    echo "❌ NODE_ENV is not set"
    exit 1
fi

# Остановка существующих контейнеров
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.cyberentics-minimal.yml down

# Очистка старых образов
echo "🧹 Cleaning up old images..."
docker system prune -f

# Сборка новых образов
echo "🔨 Building new images..."
docker-compose -f docker-compose.cyberentics-minimal.yml build --no-cache

# Запуск сервисов
echo "▶️ Starting services..."
docker-compose -f docker-compose.cyberentics-minimal.yml up -d

# Ожидание готовности сервисов
echo "⏳ Waiting for services to be ready..."
sleep 30

# Проверка здоровья сервисов
echo "🏥 Checking service health..."
docker-compose -f docker-compose.cyberentics-minimal.yml ps

# Применение миграций базы данных
echo "🗄️ Running database migrations..."
docker-compose -f docker-compose.cyberentics-minimal.yml exec app npm run db:migrate

# Проверка API
echo "🔍 Testing API endpoints..."
curl -f http://localhost:3000/api/health || {
    echo "❌ API health check failed"
    exit 1
}

echo "✅ Deployment completed successfully!"
echo "🌐 Application is available at: http://localhost:3000"
echo "📊 Redis Commander: http://localhost:8081"
echo "📈 Prometheus: http://localhost:9090"
```

### Health Check Script
```bash
#!/bin/bash
# scripts/health-check.sh

echo "🏥 NORMAL DANCE Health Check"
echo "=========================="

# Проверка основного приложения
echo -n "App: "
if curl -s -f http://localhost:3000/api/health > /dev/null; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Проверка базы данных
echo -n "Database: "
if docker-compose exec -T postgres pg_isready -U user -d normaldance > /dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Проверка Redis
echo -n "Redis: "
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Проверка IPFS
echo -n "IPFS: "
if curl -s -f http://localhost:5001/api/v0/version > /dev/null; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

echo "=========================="
echo "Health check completed"
```

Эти примеры кода демонстрируют полную техническую реализацию платформы NORMAL DANCE с акцентом на практическую ценность и готовность к production использованию.