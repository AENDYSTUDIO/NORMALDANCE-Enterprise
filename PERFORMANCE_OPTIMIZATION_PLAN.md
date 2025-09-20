# ⚡ NORMALDANCE - План оптимизации производительности

## 🎯 Цели оптимизации

- **Время загрузки:** < 2 секунды
- **Audio latency:** < 100ms
- **Cache hit ratio:** > 90%
- **Memory usage:** < 512MB per instance
- **CPU usage:** < 70% under normal load

---

## 🚀 1. Оптимизация аудио системы

### 📊 Текущие проблемы
- Синхронная обработка больших буферов
- Неэффективная очистка кэша
- Отсутствие предиктивной загрузки

### 💡 Решения

#### 1.1 Web Workers для аудио обработки
```typescript
// src/workers/audio-processor.worker.ts
class AudioProcessorWorker {
  private decoder = new AudioDecoder()
  
  async processAudio(buffer: ArrayBuffer): Promise<ProcessedAudio> {
    // Декодирование в отдельном потоке
    const decoded = await this.decoder.decode(buffer)
    
    // Применение эффектов
    const processed = await this.applyEffects(decoded)
    
    // Сжатие для передачи
    return this.compress(processed)
  }
  
  private async applyEffects(audio: AudioBuffer): Promise<AudioBuffer> {
    // Нормализация громкости
    // EQ коррекция
    // Noise reduction
    return audio
  }
}
```

#### 1.2 Streaming декодирование
```typescript
// src/lib/streaming-audio-decoder.ts
export class StreamingAudioDecoder {
  private chunks: AudioBuffer[] = []
  private isDecoding = false
  
  async decodeStream(
    stream: ReadableStream<Uint8Array>,
    onChunkReady: (chunk: AudioBuffer) => void
  ): Promise<void> {
    const reader = stream.getReader()
    
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      
      // Декодируем чанк асинхронно
      this.decodeChunkAsync(value.buffer, onChunkReady)
    }
  }
  
  private async decodeChunkAsync(
    buffer: ArrayBuffer,
    callback: (chunk: AudioBuffer) => void
  ): Promise<void> {
    // Используем Web Audio API для декодирования
    const audioContext = new AudioContext()
    try {
      const audioBuffer = await audioContext.decodeAudioData(buffer)
      callback(audioBuffer)
    } catch (error) {
      console.warn('Failed to decode audio chunk:', error)
    }
  }
}
```

#### 1.3 Предиктивное кэширование
```typescript
// src/lib/predictive-cache.ts
export class PredictiveCacheManager {
  private userBehavior = new Map<string, UserPattern>()
  private preloadQueue = new Set<string>()
  
  analyzeUserBehavior(userId: string, trackId: string): void {
    const pattern = this.userBehavior.get(userId) || new UserPattern()
    pattern.addTrack(trackId)
    
    // Предсказываем следующие треки
    const predictions = pattern.predictNext(3)
    predictions.forEach(id => this.schedulePreload(id))
  }
  
  private async schedulePreload(trackId: string): Promise<void> {
    if (this.preloadQueue.has(trackId)) return
    
    this.preloadQueue.add(trackId)
    
    // Предзагружаем с низким приоритетом
    requestIdleCallback(() => {
      this.preloadTrack(trackId)
      this.preloadQueue.delete(trackId)
    })
  }
}
```

---

## 🗄️ 2. Оптимизация кэширования

### 📊 Многоуровневая архитектура кэша

```typescript
// src/lib/tiered-cache.ts
export class TieredCacheSystem {
  constructor(
    private l1: MemoryCache,     // 100MB, 1ms latency
    private l2: RedisCache,      // 1GB, 5ms latency  
    private l3: IPFSCache        // Unlimited, 100ms latency
  ) {}
  
  async get<T>(key: string): Promise<T | null> {
    // L1: Memory cache
    let value = await this.l1.get<T>(key)
    if (value) {
      this.recordHit('l1')
      return value
    }
    
    // L2: Redis cache
    value = await this.l2.get<T>(key)
    if (value) {
      this.recordHit('l2')
      // Promote to L1
      await this.l1.set(key, value, 300) // 5 min TTL
      return value
    }
    
    // L3: IPFS cache
    value = await this.l3.get<T>(key)
    if (value) {
      this.recordHit('l3')
      // Promote to L2 and L1
      await this.l2.set(key, value, 3600) // 1 hour TTL
      await this.l1.set(key, value, 300)  // 5 min TTL
      return value
    }
    
    this.recordMiss()
    return null
  }
  
  async set<T>(key: string, value: T, ttl: number): Promise<void> {
    // Write to all levels
    await Promise.all([
      this.l1.set(key, value, Math.min(ttl, 300)),
      this.l2.set(key, value, Math.min(ttl, 3600)),
      this.l3.set(key, value, ttl)
    ])
  }
}
```

### 📈 Cache warming стратегия

```typescript
// src/lib/cache-warmer.ts
export class CacheWarmer {
  private warmingSchedule = new Map<string, number>()
  
  async warmPopularContent(): Promise<void> {
    // Получаем топ треков за последние 24 часа
    const popularTracks = await this.getPopularTracks(24)
    
    // Предзагружаем в порядке популярности
    for (const track of popularTracks) {
      await this.warmTrack(track.id, track.popularity)
      
      // Throttling чтобы не перегрузить систему
      await this.sleep(100)
    }
  }
  
  private async warmTrack(trackId: string, priority: number): Promise<void> {
    const profiles = this.selectProfilesByPriority(priority)
    
    for (const profile of profiles) {
      try {
        const audio = await this.loadTrack(trackId, profile)
        await this.cache.set(`track:${trackId}:${profile}`, audio, 3600)
      } catch (error) {
        console.warn(`Failed to warm track ${trackId}:`, error)
      }
    }
  }
}
```

---

## 🎨 3. Оптимизация React компонентов

### 📦 Code Splitting и Lazy Loading

```typescript
// src/components/lazy-components.tsx
import { lazy, Suspense } from 'react'
import { ComponentSkeleton } from './ui/skeleton'

// Lazy load тяжелых компонентов
const AudioPlayer = lazy(() => import('./audio/audio-player'))
const WalletConnect = lazy(() => import('./wallet/wallet-connect'))
const NFTGallery = lazy(() => import('./nft/nft-gallery'))
const StakingDashboard = lazy(() => import('./staking/staking-dashboard'))

// HOC для lazy loading с fallback
export function withLazyLoading<T extends object>(
  Component: React.ComponentType<T>,
  fallback?: React.ReactNode
) {
  return function LazyComponent(props: T) {
    return (
      <Suspense fallback={fallback || <ComponentSkeleton />}>
        <Component {...props} />
      </Suspense>
    )
  }
}

// Предзагрузка компонентов при hover
export function preloadComponent(componentImport: () => Promise<any>) {
  return {
    onMouseEnter: () => componentImport(),
    onFocus: () => componentImport()
  }
}
```

### 🔄 Мемоизация и оптимизация рендеринга

```typescript
// src/hooks/use-optimized-audio.ts
export function useOptimizedAudio(trackId: string) {
  // Мемоизируем аудио данные
  const audioData = useMemo(() => {
    return audioCache.get(trackId)
  }, [trackId])
  
  // Дебаунс для частых обновлений
  const debouncedSeek = useCallback(
    debounce((position: number) => {
      audioPlayer.seek(position)
    }, 100),
    []
  )
  
  // Виртуализация для больших плейлистов
  const virtualizedTracks = useMemo(() => {
    return new VirtualizedList(tracks, {
      itemHeight: 60,
      overscan: 5
    })
  }, [tracks])
  
  return {
    audioData,
    seek: debouncedSeek,
    virtualizedTracks
  }
}
```

### 🎯 Оптимизация стилей

```typescript
// src/styles/optimized-styles.ts
import { createGlobalStyle } from 'styled-components'

// CSS-in-JS с оптимизацией
export const OptimizedGlobalStyles = createGlobalStyle`
  /* Critical CSS inline */
  .audio-player {
    contain: layout style paint;
    will-change: transform;
  }
  
  /* Lazy load non-critical styles */
  .nft-gallery {
    content-visibility: auto;
    contain-intrinsic-size: 300px;
  }
  
  /* GPU acceleration для анимаций */
  .smooth-animation {
    transform: translateZ(0);
    backface-visibility: hidden;
  }
`

// Динамическая загрузка CSS
export async function loadCriticalCSS() {
  const css = await import('./critical.css')
  return css.default
}
```

---

## 📊 4. Database оптимизация

### 🗃️ Query оптимизация

```sql
-- Индексы для частых запросов
CREATE INDEX CONCURRENTLY idx_tracks_popularity 
ON tracks (popularity DESC, created_at DESC);

CREATE INDEX CONCURRENTLY idx_user_playlists 
ON playlists (user_id, updated_at DESC);

CREATE INDEX CONCURRENTLY idx_audio_metadata 
ON tracks USING GIN (metadata);

-- Партиционирование больших таблиц
CREATE TABLE play_history (
  id BIGSERIAL,
  user_id UUID NOT NULL,
  track_id UUID NOT NULL,
  played_at TIMESTAMP NOT NULL,
  duration INTEGER
) PARTITION BY RANGE (played_at);

-- Партиции по месяцам
CREATE TABLE play_history_2025_01 PARTITION OF play_history
FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

### 📈 Connection pooling

```typescript
// src/lib/db-pool.ts
export class OptimizedDBPool {
  private pool: Pool
  
  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      
      // Оптимизированные настройки пула
      min: 5,                    // Минимум соединений
      max: 20,                   // Максимум соединений
      idleTimeoutMillis: 30000,  // Таймаут неактивных соединений
      connectionTimeoutMillis: 2000, // Таймаут подключения
      
      // Настройки для производительности
      statement_timeout: 10000,   // 10 секунд на запрос
      query_timeout: 5000,        // 5 секунд на выполнение
      
      // SSL для production
      ssl: process.env.NODE_ENV === 'production' ? {
        rejectUnauthorized: false
      } : false
    })
  }
  
  async query<T>(text: string, params?: any[]): Promise<QueryResult<T>> {
    const start = Date.now()
    
    try {
      const result = await this.pool.query(text, params)
      
      // Мониторинг производительности
      const duration = Date.now() - start
      if (duration > 1000) {
        console.warn(`Slow query detected: ${duration}ms`, { text, params })
      }
      
      return result
    } catch (error) {
      console.error('Database query failed:', { text, params, error })
      throw error
    }
  }
}
```

---

## 🌐 5. CDN и статические ресурсы

### 📦 Asset оптимизация

```typescript
// next.config.js
module.exports = {
  images: {
    domains: ['cdn.normaldance.com'],
    formats: ['image/webp', 'image/avif'],
    minimumCacheTTL: 86400, // 24 часа
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384]
  },
  
  // Сжатие
  compress: true,
  
  // Оптимизация бандла
  webpack: (config, { dev, isServer }) => {
    if (!dev && !isServer) {
      // Tree shaking
      config.optimization.usedExports = true
      
      // Bundle splitting
      config.optimization.splitChunks = {
        chunks: 'all',
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendors',
            chunks: 'all',
          },
          audio: {
            test: /[\\/]audio[\\/]/,
            name: 'audio',
            chunks: 'all',
          }
        }
      }
    }
    
    return config
  }
}
```

### 🚀 Service Worker для кэширования

```typescript
// public/sw.js
const CACHE_NAME = 'normaldance-v1'
const AUDIO_CACHE = 'normaldance-audio-v1'

// Стратегии кэширования
const cacheStrategies = {
  // Статические ресурсы - cache first
  static: /\.(js|css|png|jpg|jpeg|gif|svg|woff2?)$/,
  
  // API - network first с fallback
  api: /^\/api\//,
  
  // Аудио файлы - cache first с обновлением в фоне
  audio: /\.(mp3|wav|flac|aac|ogg)$/
}

self.addEventListener('fetch', event => {
  const { request } = event
  const url = new URL(request.url)
  
  // Аудио файлы
  if (cacheStrategies.audio.test(url.pathname)) {
    event.respondWith(audioCache(request))
  }
  // API запросы
  else if (cacheStrategies.api.test(url.pathname)) {
    event.respondWith(networkFirst(request))
  }
  // Статические ресурсы
  else if (cacheStrategies.static.test(url.pathname)) {
    event.respondWith(cacheFirst(request))
  }
})

async function audioCache(request) {
  const cache = await caches.open(AUDIO_CACHE)
  const cached = await cache.match(request)
  
  if (cached) {
    // Обновляем в фоне
    fetch(request).then(response => {
      if (response.ok) {
        cache.put(request, response.clone())
      }
    })
    return cached
  }
  
  // Загружаем и кэшируем
  const response = await fetch(request)
  if (response.ok) {
    cache.put(request, response.clone())
  }
  return response
}
```

---

## 📊 6. Мониторинг производительности

### 📈 Real User Monitoring (RUM)

```typescript
// src/lib/performance-monitor.ts
export class PerformanceMonitor {
  private metrics = new Map<string, number[]>()
  
  // Web Vitals мониторинг
  measureWebVitals(): void {
    // First Contentful Paint
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (entry.name === 'first-contentful-paint') {
          this.recordMetric('fcp', entry.startTime)
        }
      }
    }).observe({ entryTypes: ['paint'] })
    
    // Largest Contentful Paint
    new PerformanceObserver((list) => {
      const entries = list.getEntries()
      const lastEntry = entries[entries.length - 1]
      this.recordMetric('lcp', lastEntry.startTime)
    }).observe({ entryTypes: ['largest-contentful-paint'] })
    
    // Cumulative Layout Shift
    let clsValue = 0
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (!entry.hadRecentInput) {
          clsValue += entry.value
        }
      }
      this.recordMetric('cls', clsValue)
    }).observe({ entryTypes: ['layout-shift'] })
  }
  
  // Аудио специфичные метрики
  measureAudioPerformance(): void {
    const audioContext = new AudioContext()
    
    // Latency мониторинг
    setInterval(() => {
      const latency = audioContext.outputLatency || 0
      this.recordMetric('audio_latency', latency * 1000) // в миллисекундах
    }, 1000)
    
    // Buffer underruns
    this.monitorBufferUnderruns()
  }
  
  private recordMetric(name: string, value: number): void {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, [])
    }
    
    const values = this.metrics.get(name)!
    values.push(value)
    
    // Ограничиваем размер массива
    if (values.length > 100) {
      values.shift()
    }
    
    // Отправляем критические метрики
    if (this.isCriticalMetric(name, value)) {
      this.sendAlert(name, value)
    }
  }
  
  private isCriticalMetric(name: string, value: number): boolean {
    const thresholds = {
      fcp: 2500,        // 2.5 секунды
      lcp: 4000,        // 4 секунды
      cls: 0.25,        // 0.25
      audio_latency: 150 // 150ms
    }
    
    return value > (thresholds[name as keyof typeof thresholds] || Infinity)
  }
}
```

### 🎯 Performance Budget

```json
{
  "performanceBudget": {
    "resourceSizes": [
      {
        "resourceType": "script",
        "budget": 400
      },
      {
        "resourceType": "total",
        "budget": 2000
      }
    ],
    "resourceCounts": [
      {
        "resourceType": "third-party",
        "budget": 10
      }
    ]
  },
  "budgets": [
    {
      "type": "bundle",
      "name": "main",
      "baseline": "500kb",
      "maximum": "1mb"
    },
    {
      "type": "initial",
      "maximum": "2mb"
    }
  ]
}
```

---

## 🚀 7. План внедрения

### 📅 Фаза 1 (Неделя 1-2): Критические оптимизации
- [ ] Реализовать code splitting
- [ ] Добавить lazy loading компонентов
- [ ] Оптимизировать кэш очистку
- [ ] Настроить performance monitoring

### 📅 Фаза 2 (Неделя 3-4): Аудио оптимизация
- [ ] Внедрить Web Workers
- [ ] Реализовать streaming декодирование
- [ ] Добавить предиктивное кэширование
- [ ] Оптимизировать audio buffer management

### 📅 Фаза 3 (Неделя 5-6): Инфраструктурные улучшения
- [ ] Настроить многоуровневое кэширование
- [ ] Оптимизировать database queries
- [ ] Внедрить CDN для статических ресурсов
- [ ] Добавить Service Worker

### 📅 Фаза 4 (Неделя 7-8): Мониторинг и тюнинг
- [ ] Настроить Real User Monitoring
- [ ] Добавить performance budgets
- [ ] Провести нагрузочное тестирование
- [ ] Финальная оптимизация на основе метрик

---

## 📊 8. Ожидаемые результаты

### 🎯 Целевые метрики после оптимизации

| Метрика | До оптимизации | После оптимизации | Улучшение |
|---------|----------------|-------------------|-----------|
| First Contentful Paint | 3.2s | 1.4s | 56% |
| Largest Contentful Paint | 4.8s | 2.1s | 56% |
| Time to Interactive | 5.1s | 2.8s | 45% |
| Audio Latency | 200ms | 80ms | 60% |
| Cache Hit Ratio | 65% | 92% | 42% |
| Bundle Size | 2.1MB | 1.2MB | 43% |
| Memory Usage | 680MB | 420MB | 38% |

### 💰 Бизнес эффект
- **Увеличение конверсии:** +25% (за счет быстрой загрузки)
- **Снижение bounce rate:** -35% (лучший UX)
- **Экономия на инфраструктуре:** -30% (оптимизация ресурсов)
- **Улучшение retention:** +20% (плавное воспроизведение аудио)

---

*План подготовлен: 2025-01-27*  
*Ответственный за реализацию: Development Team*  
*Контроль выполнения: еженедельные ретроспективы*