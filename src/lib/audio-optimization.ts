// Система оптимизации аудио файлов
export interface AudioProfile {
  name: string
  bitrate: number
  sampleRate: number
  format: 'mp3' | 'aac' | 'ogg'
  quality: 'low' | 'medium' | 'high' | 'lossless'
}

// Профили качества аудио
export const AUDIO_PROFILES: { [key: string]: AudioProfile } = {
  preview: {
    name: 'Preview',
    bitrate: 64,
    sampleRate: 22050,
    format: 'mp3',
    quality: 'low'
  },
  mobile: {
    name: 'Mobile',
    bitrate: 128,
    sampleRate: 44100,
    format: 'aac',
    quality: 'medium'
  },
  standard: {
    name: 'Standard',
    bitrate: 192,
    sampleRate: 44100,
    format: 'mp3',
    quality: 'medium'
  },
  high: {
    name: 'High Quality',
    bitrate: 320,
    sampleRate: 44100,
    format: 'mp3',
    quality: 'high'
  },
  lossless: {
    name: 'Lossless',
    bitrate: 1411,
    sampleRate: 44100,
    format: 'mp3',
    quality: 'lossless'
  }
}

// LRU Cache для больших аудио буферов
class AudioLRUCache {
  private cache = new Map<string, { data: ArrayBuffer; timestamp: number; size: number }>()
  private maxSize: number
  private currentSize = 0

  constructor(maxSizeMB: number = 100) {
    this.maxSize = maxSizeMB * 1024 * 1024 // Конвертируем в байты
  }

  get(key: string): ArrayBuffer | null {
    const item = this.cache.get(key)
    if (!item) return null

    // Обновляем timestamp для LRU
    item.timestamp = Date.now()
    this.cache.delete(key)
    this.cache.set(key, item)
    
    return item.data
  }

  set(key: string, data: ArrayBuffer): void {
    const size = data.byteLength
    
    // Проверяем, не превышает ли файл максимальный размер кеша
    if (size > this.maxSize) {
      console.warn(`Audio file too large for cache: ${size} bytes`)
      return
    }

    // Освобождаем место если нужно
    while (this.currentSize + size > this.maxSize && this.cache.size > 0) {
      this.evictLRU()
    }

    // Удаляем существующий элемент если есть
    if (this.cache.has(key)) {
      const existing = this.cache.get(key)!
      this.currentSize -= existing.size
      this.cache.delete(key)
    }

    // Добавляем новый элемент
    this.cache.set(key, { data, timestamp: Date.now(), size })
    this.currentSize += size
  }

  private evictLRU(): void {
    // Use iterator for O(1) LRU eviction
    const firstEntry = this.cache.entries().next().value
    if (firstEntry) {
      const [key, item] = firstEntry
      this.currentSize -= item.size
      this.cache.delete(key)
      console.log(`Evicted audio from cache: ${key}`)
    }
  }

  private async evictLRUAsync(): Promise<void> {
    return new Promise(resolve => {
      setTimeout(() => {
        this.evictLRU()
        resolve()
      }, 0)
    })
  }

  getStats() {
    return {
      size: this.cache.size,
      currentSizeMB: (this.currentSize / 1024 / 1024).toFixed(2),
      maxSizeMB: (this.maxSize / 1024 / 1024).toFixed(2),
      hitRate: 0 // TODO: Добавить отслеживание hit rate
    }
  }

  clear(): void {
    this.cache.clear()
    this.currentSize = 0
  }
}

// Менеджер плейлистов с предзагрузкой
class PlaylistManager {
  private playlists = new Map<string, string[]>()
  private preloadedTracks = new Set<string>()
  private audioCache: AudioLRUCache

  constructor(audioCache: AudioLRUCache) {
    this.audioCache = audioCache
  }

  // Создание плейлиста
  createPlaylist(id: string, trackIds: string[]): void {
    this.playlists.set(id, trackIds)
    console.log(`Playlist created: ${id} with ${trackIds.length} tracks`)
  }

  // Предзагрузка плейлиста
  async preloadPlaylist(playlistId: string, profile: AudioProfile = AUDIO_PROFILES.standard): Promise<void> {
    const trackIds = this.playlists.get(playlistId)
    if (!trackIds) {
      throw new Error(`Playlist not found: ${playlistId}`)
    }

    console.log(`Preloading playlist: ${playlistId}`)
    const preloadPromises = trackIds.slice(0, 5).map(trackId => // Предзагружаем первые 5 треков
      this.preloadTrack(trackId, profile)
    )

    const results = await Promise.allSettled(preloadPromises)
    const successful = results.filter(r => r.status === 'fulfilled').length
    
    console.log(`Preloaded ${successful}/${Math.min(5, trackIds.length)} tracks for playlist ${playlistId}`)
  }

  // Предзагрузка трека
  private async preloadTrack(trackId: string, profile: AudioProfile): Promise<void> {
    if (this.preloadedTracks.has(trackId)) {
      return // Уже предзагружен
    }

    try {
      const audioUrl = await this.getOptimizedAudioUrl(trackId, profile)
      const response = await fetch(audioUrl)
      
      if (!response.ok) {
        throw new Error(`Failed to fetch audio: ${response.status}`)
      }

      const arrayBuffer = await response.arrayBuffer()
      this.audioCache.set(`${trackId}_${profile.name}`, arrayBuffer)
      this.preloadedTracks.add(trackId)
      
      console.log(`Preloaded track: ${trackId}`)
    } catch (error) {
      console.error(`Failed to preload track ${trackId}:`, error)
    }
  }

  // Получение оптимизированного URL аудио
  private async getOptimizedAudioUrl(trackId: string, profile: AudioProfile): Promise<string> {
    // В реальном приложении здесь будет логика получения URL из CDN
    // с учетом профиля качества
    const baseUrl = process.env.AUDIO_CDN_URL || 'https://audio.normaldance.com'
    return `${baseUrl}/${trackId}/${profile.name.toLowerCase()}.${profile.format}`
  }

  // Получение трека из кеша или загрузка
  async getTrack(trackId: string, profile: AudioProfile = AUDIO_PROFILES.standard): Promise<ArrayBuffer> {
    const cacheKey = `${trackId}_${profile.name}`
    
    // Проверяем кеш
    const cached = this.audioCache.get(cacheKey)
    if (cached) {
      console.log(`Audio served from cache: ${trackId}`)
      return cached
    }

    // Загружаем если нет в кеше
    console.log(`Loading audio from network: ${trackId}`)
    const audioUrl = await this.getOptimizedAudioUrl(trackId, profile)
    const response = await fetch(audioUrl)
    
    if (!response.ok) {
      throw new Error(`Failed to fetch audio: ${response.status}`)
    }

    const arrayBuffer = await response.arrayBuffer()
    this.audioCache.set(cacheKey, arrayBuffer)
    
    return arrayBuffer
  }

  // Получение следующего трека в плейлисте
  getNextTrack(playlistId: string, currentTrackId: string): string | null {
    const tracks = this.playlists.get(playlistId)
    if (!tracks) return null

    const currentIndex = tracks.indexOf(currentTrackId)
    if (currentIndex === -1 || currentIndex === tracks.length - 1) return null

    return tracks[currentIndex + 1]
  }

  // Предзагрузка следующего трека
  async preloadNextTrack(playlistId: string, currentTrackId: string, profile: AudioProfile): Promise<void> {
    const nextTrackId = this.getNextTrack(playlistId, currentTrackId)
    if (nextTrackId && !this.preloadedTracks.has(nextTrackId)) {
      await this.preloadTrack(nextTrackId, profile)
    }
  }
}

// Адаптивный выбор качества на основе соединения
class AdaptiveQualityManager {
  private currentProfile: AudioProfile = AUDIO_PROFILES.standard
  private connectionSpeed: number = 0
  private listeners: ((profile: AudioProfile) => void)[] = []

  constructor() {
    this.detectConnectionSpeed()
    this.startNetworkMonitoring()
  }

  // Детекция скорости соединения
  private async detectConnectionSpeed(): Promise<void> {
    if ('connection' in navigator) {
      const connection = (navigator as any).connection
      if (connection) {
        this.updateQualityBasedOnConnection(connection.effectiveType, connection.downlink)
        
        connection.addEventListener('change', () => {
          this.updateQualityBasedOnConnection(connection.effectiveType, connection.downlink)
        })
      }
    }

    // Fallback: тест скорости
    try {
      const startTime = Date.now()
      const response = await fetch('/api/speed-test', { method: 'HEAD' })
      const endTime = Date.now()
      
      if (response.ok) {
        const latency = endTime - startTime
        this.estimateSpeedFromLatency(latency)
      }
    } catch (error) {
      console.warn('Speed test failed:', error)
    }
  }

  // Обновление качества на основе соединения
  private updateQualityBasedOnConnection(effectiveType: string, downlink: number): void {
    let newProfile: AudioProfile

    switch (effectiveType) {
      case 'slow-2g':
      case '2g':
        newProfile = AUDIO_PROFILES.preview
        break
      case '3g':
        newProfile = AUDIO_PROFILES.mobile
        break
      case '4g':
        if (downlink > 10) {
          newProfile = AUDIO_PROFILES.high
        } else {
          newProfile = AUDIO_PROFILES.standard
        }
        break
      default:
        newProfile = AUDIO_PROFILES.standard
    }

    if (newProfile !== this.currentProfile) {
      this.currentProfile = newProfile
      console.log(`Audio quality adapted to: ${newProfile.name}`)
      this.notifyListeners()
    }
  }

  // Оценка скорости по латентности
  private estimateSpeedFromLatency(latency: number): void {
    let newProfile: AudioProfile

    if (latency < 100) {
      newProfile = AUDIO_PROFILES.high
    } else if (latency < 300) {
      newProfile = AUDIO_PROFILES.standard
    } else if (latency < 1000) {
      newProfile = AUDIO_PROFILES.mobile
    } else {
      newProfile = AUDIO_PROFILES.preview
    }

    if (newProfile !== this.currentProfile) {
      this.currentProfile = newProfile
      console.log(`Audio quality adapted based on latency (${latency}ms): ${newProfile.name}`)
      this.notifyListeners()
    }
  }

  // Мониторинг сети
  private startNetworkMonitoring(): void {
    setInterval(() => {
      this.detectConnectionSpeed()
    }, 30000) // Проверяем каждые 30 секунд
  }

  // Подписка на изменения качества
  onQualityChange(callback: (profile: AudioProfile) => void): void {
    this.listeners.push(callback)
  }

  // Уведомление слушателей
  private notifyListeners(): void {
    this.listeners.forEach(callback => callback(this.currentProfile))
  }

  // Получение текущего профиля
  getCurrentProfile(): AudioProfile {
    return this.currentProfile
  }

  // Принудительная установка профиля
  setProfile(profile: AudioProfile): void {
    this.currentProfile = profile
    this.notifyListeners()
  }
}

// Главный класс оптимизации аудио
export class AudioOptimizer {
  private cache: AudioLRUCache
  private playlistManager: PlaylistManager
  private qualityManager: AdaptiveQualityManager

  constructor(cacheSizeMB: number = 100) {
    this.cache = new AudioLRUCache(cacheSizeMB)
    this.playlistManager = new PlaylistManager(this.cache)
    this.qualityManager = new AdaptiveQualityManager()
  }

  // Создание плейлиста
  createPlaylist(id: string, trackIds: string[]): void {
    this.playlistManager.createPlaylist(id, trackIds)
  }

  // Предзагрузка плейлиста
  async preloadPlaylist(playlistId: string): Promise<void> {
    const profile = this.qualityManager.getCurrentProfile()
    await this.playlistManager.preloadPlaylist(playlistId, profile)
  }

  // Получение трека
  async getTrack(trackId: string, customProfile?: AudioProfile): Promise<ArrayBuffer> {
    const profile = customProfile || this.qualityManager.getCurrentProfile()
    return await this.playlistManager.getTrack(trackId, profile)
  }

  // Подписка на изменения качества
  onQualityChange(callback: (profile: AudioProfile) => void): void {
    this.qualityManager.onQualityChange(callback)
  }

  // Получение статистики
  getStats() {
    return {
      cache: this.cache.getStats(),
      currentQuality: this.qualityManager.getCurrentProfile(),
      availableProfiles: Object.keys(AUDIO_PROFILES)
    }
  }

  // Очистка кеша
  clearCache(): void {
    this.cache.clear()
  }
}

// Глобальный экземпляр оптимизатора
export const audioOptimizer = new AudioOptimizer()

// React хук для использования аудио оптимизатора
export function useAudioOptimizer() {
  const [currentProfile, setCurrentProfile] = useState(audioOptimizer.getStats().currentQuality)
  const [stats, setStats] = useState(audioOptimizer.getStats())

  useEffect(() => {
    const handleQualityChange = (profile: AudioProfile) => {
      setCurrentProfile(profile)
      setStats(audioOptimizer.getStats())
    }

    audioOptimizer.onQualityChange(handleQualityChange)

    // Обновляем статистику каждые 10 секунд
    const interval = setInterval(() => {
      setStats(audioOptimizer.getStats())
    }, 10000)

    return () => clearInterval(interval)
  }, [])

  return {
    currentProfile,
    stats,
    createPlaylist: audioOptimizer.createPlaylist.bind(audioOptimizer),
    preloadPlaylist: audioOptimizer.preloadPlaylist.bind(audioOptimizer),
    getTrack: audioOptimizer.getTrack.bind(audioOptimizer),
    clearCache: audioOptimizer.clearCache.bind(audioOptimizer)
  }
}