const EventEmitter = require('events');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');
const { promisify } = require('util');

const gzip = promisify(zlib.gzip);
const gunzip = promisify(zlib.gunzip);

class CacheManager extends EventEmitter {
  constructor(redisClient, logger, metricsCollector) {
    super();
    this.redis = redisClient;
    this.logger = logger;
    this.metrics = metricsCollector;
    
    // Конфигурация
    this.config = {
      cacheDir: './cache',
      maxCacheSize: 1024 * 1024 * 1024 * 10, // 10GB
      maxFileAge: 24 * 60 * 60 * 1000, // 24 часа
      cleanupInterval: 5 * 60 * 1000, // 5 минут
      compressionLevel: 6,
      memoryCacheSize: 100, // количество файлов в памяти
      redisTTL: 3600, // 1 час
      prefetchEnabled: true,
      prefetchThreshold: 0.8 // 80% буфера
    };
    
    // Состояние
    this.memoryCache = new Map();
    this.accessLog = new Map();
    this.fileSizes = new Map();
    this.cleanupQueue = [];
    
    // Таймеры
    this.cleanupTimer = null;
    this.statsTimer = null;
    
    // Статистика
    this.stats = {
      hits: 0,
      misses: 0,
      evictions: 0,
      totalSize: 0,
      fileCount: 0
    };
    
    this.initialize();
  }

  async initialize() {
    this.logger.info('CacheManager initializing...');
    
    // Создание директорий
    await this.ensureDirectories();
    
    // Загрузка метаданных
    await this.loadMetadata();
    
    // Запуск периодических задач
    this.startPeriodicTasks();
    
    this.logger.info('CacheManager initialized');
  }

  async ensureDirectories() {
    const dirs = [
      this.config.cacheDir,
      path.join(this.config.cacheDir, 'audio'),
      path.join(this.config.cacheDir, 'metadata'),
      path.join(this.config.cacheDir, 'temp')
    ];
    
    for (const dir of dirs) {
      try {
        await fs.mkdir(dir, { recursive: true });
      } catch (error) {
        this.logger.error(`Error creating directory ${dir}:`, error);
      }
    }
  }

  // Основные методы кэширования
  async get(key, options = {}) {
    const cacheKey = this.generateCacheKey(key);
    
    try {
      // Проверка в памяти
      const memoryHit = this.memoryCache.get(cacheKey);
      if (memoryHit && !this.isExpired(memoryHit)) {
        this.updateAccessLog(cacheKey);
        this.stats.hits++;
        this.emit('cache:hit', { key, source: 'memory' });
        return memoryHit.data;
      }
      
      // Проверка в Redis
      const redisData = await this.redis.get(`cache:${cacheKey}`);
      if (redisData) {
        const parsed = JSON.parse(redisData);
        if (!this.isExpired(parsed)) {
          this.updateAccessLog(cacheKey);
          this.stats.hits++;
          
          // Кэширование в памяти
          this.cacheInMemory(cacheKey, parsed);
          
          this.emit('cache:hit', { key, source: 'redis' });
          return parsed.data;
        }
      }
      
      // Проверка в файловой системе
      const filePath = this.getFilePath(cacheKey);
      try {
        const fileData = await fs.readFile(filePath);
        const entry = JSON.parse(fileData.toString());
        
        if (!this.isExpired(entry)) {
          this.updateAccessLog(cacheKey);
          this.stats.hits++;
          
          // Кэширование в Redis и памяти
          await this.cacheInRedis(cacheKey, entry);
          this.cacheInMemory(cacheKey, entry);
          
          this.emit('cache:hit', { key, source: 'filesystem' });
          return entry.data;
        } else {
          // Удаление устаревшего файла
          await fs.unlink(filePath);
        }
      } catch (error) {
        if (error.code !== 'ENOENT') {
          this.logger.error('Error reading cache file:', error);
        }
      }
      
      this.stats.misses++;
      this.emit('cache:miss', { key });
      return null;
      
    } catch (error) {
      this.logger.error('Error getting from cache:', error);
      return null;
    }
  }

  async set(key, data, options = {}) {
    const cacheKey = this.generateCacheKey(key);
    const ttl = options.ttl || this.config.redisTTL;
    const compress = options.compress !== false;
    
    try {
      const entry = {
        data,
        timestamp: Date.now(),
        ttl: ttl * 1000,
        size: Buffer.isBuffer(data) ? data.length : JSON.stringify(data).length,
        compressed: compress
      };
      
      // Сжатие данных
      let processedData = data;
      if (compress && Buffer.isBuffer(data)) {
        processedData = await gzip(data);
        entry.size = processedData.length;
      }
      
      entry.data = processedData;
      
      // Кэширование в памяти
      this.cacheInMemory(cacheKey, entry);
      
      // Кэширование в Redis
      await this.cacheInRedis(cacheKey, entry, ttl);
      
      // Кэширование в файловой системе
      if (options.persist !== false) {
        await this.cacheInFilesystem(cacheKey, entry);
      }
      
      this.emit('cache:set', { key, size: entry.size });
      
    } catch (error) {
      this.logger.error('Error setting cache:', error);
    }
  }

  async delete(key) {
    const cacheKey = this.generateCacheKey(key);
    
    try {
      // Удаление из памяти
      this.memoryCache.delete(cacheKey);
      
      // Удаление из Redis
      await this.redis.del(`cache:${cacheKey}`);
      
      // Удаление из файловой системы
      const filePath = this.getFilePath(cacheKey);
      try {
        await fs.unlink(filePath);
      } catch (error) {
        if (error.code !== 'ENOENT') {
          throw error;
        }
      }
      
      // Удаление из логов
      this.accessLog.delete(cacheKey);
      this.fileSizes.delete(cacheKey);
      
      this.emit('cache:deleted', { key });
      
    } catch (error) {
      this.logger.error('Error deleting from cache:', error);
    }
  }

  // Специализированные методы для аудио
  async cacheAudioSegment(trackId, segmentIndex, data, quality, metadata = {}) {
    const key = `audio:${trackId}:${quality}:${segmentIndex}`;
    const ttl = 24 * 3600; // 24 часа
    
    await this.set(key, data, {
      ttl,
      compress: true,
      persist: true,
      metadata: {
        trackId,
        segmentIndex,
        quality,
        ...metadata
      }
    });
  }

  async getAudioSegment(trackId, segmentIndex, quality) {
    const key = `audio:${trackId}:${quality}:${segmentIndex}`;
    return await this.get(key);
  }

  async cacheTrackMetadata(trackId, metadata) {
    const key = `metadata:${trackId}`;
    const ttl = 7 * 24 * 3600; // 7 дней
    
    await this.set(key, metadata, {
      ttl,
      compress: false,
      persist: true
    });
  }

  async getTrackMetadata(trackId) {
    const key = `metadata:${trackId}`;
    return await this.get(key);
  }

  async prefetchNextSegments(trackId, currentSegment, quality, count = 2) {
    if (!this.config.prefetchEnabled) {
      return;
    }
    
    const promises = [];
    
    for (let i = 1; i <= count; i++) {
      const segmentIndex = currentSegment + i;
      promises.push(
        this.generateSegment(trackId, segmentIndex, quality)
      );
    }
    
    await Promise.allSettled(promises);
  }

  async generateSegment(trackId, segmentIndex, quality) {
    // Этот метод будет вызван из AudioStreamManager
    // Здесь просто проверяем наличие в кэше
    const key = `audio:${trackId}:${quality}:${segmentIndex}`;
    const exists = await this.get(key);
    
    if (!exists) {
      this.emit('cache:prefetch_needed', {
        trackId,
        segmentIndex,
        quality
      });
    }
  }

  // Внутренние методы
  generateCacheKey(key) {
    return crypto.createHash('sha256').update(String(key)).digest('hex');
  }

  getFilePath(cacheKey) {
    return path.join(this.config.cacheDir, `${cacheKey}.cache`);
  }

  isExpired(entry) {
    return Date.now() - entry.timestamp > entry.ttl;
  }

  cacheInMemory(cacheKey, entry) {
    // Ограничение размера кэша в памяти
    if (this.memoryCache.size >= this.config.memoryCacheSize) {
      const oldestKey = this.memoryCache.keys().next().value;
      this.memoryCache.delete(oldestKey);
    }
    
    this.memoryCache.set(cacheKey, entry);
  }

  async cacheInRedis(cacheKey, entry, ttl = null) {
    try {
      const ttlSeconds = ttl || this.config.redisTTL;
      await this.redis.setex(
        `cache:${cacheKey}`,
        ttlSeconds,
        JSON.stringify(entry)
      );
    } catch (error) {
      this.logger.error('Error caching in Redis:', error);
    }
  }

  async cacheInFilesystem(cacheKey, entry) {
    try {
      const filePath = this.getFilePath(cacheKey);
      
      // Проверка общего размера кэша
      await this.checkCacheSize();
      
      await fs.writeFile(filePath, JSON.stringify(entry));
      
      this.fileSizes.set(cacheKey, entry.size);
      this.stats.totalSize += entry.size;
      this.stats.fileCount++;
      
    } catch (error) {
      this.logger.error('Error caching in filesystem:', error);
    }
  }

  async checkCacheSize() {
    if (this.stats.totalSize > this.config.maxCacheSize) {
      await this.cleanupOldFiles();
    }
  }

  async cleanupOldFiles() {
    const files = [];
    
    try {
      const dirFiles = await fs.readdir(this.config.cacheDir);
      
      for (const file of dirFiles) {
        if (file.endsWith('.cache')) {
          const filePath = path.join(this.config.cacheDir, file);
          const stats = await fs.stat(filePath);
          
          files.push({
            path: filePath,
            key: file.replace('.cache', ''),
            size: stats.size,
            lastAccess: this.accessLog.get(file.replace('.cache', '')) || stats.mtime.getTime()
          });
        }
      }
      
      // Сортировка по времени последнего доступа
      files.sort((a, b) => a.lastAccess - b.lastAccess);
      
      // Удаление старых файлов
      let removedSize = 0;
      const targetSize = this.config.maxCacheSize * 0.8;
      
      for (const file of files) {
        if (this.stats.totalSize - removedSize <= targetSize) {
          break;
        }
        
        try {
          await fs.unlink(file.path);
          removedSize += file.size;
          this.stats.evictions++;
          
          this.fileSizes.delete(file.key);
          this.accessLog.delete(file.key);
          
        } catch (error) {
          this.logger.error('Error deleting cache file:', error);
        }
      }
      
      this.stats.totalSize -= removedSize;
      
    } catch (error) {
      this.logger.error('Error during cache cleanup:', error);
    }
  }

  updateAccessLog(cacheKey) {
    this.accessLog.set(cacheKey, Date.now());
  }

  // Периодические задачи
  startPeriodicTasks() {
    this.cleanupTimer = setInterval(() => {
      this.cleanup();
    }, this.config.cleanupInterval);
    
    this.statsTimer = setInterval(() => {
      this.saveMetadata();
    }, 60000); // Каждую минуту
  }

  async cleanup() {
    try {
      // Очистка устаревших записей
      const now = Date.now();
      
      // Очистка памяти
      for (const [key, entry] of this.memoryCache.entries()) {
        if (this.isExpired(entry)) {
          this.memoryCache.delete(key);
        }
      }
      
      // Очистка Redis
      const redisKeys = await this.redis.keys('cache:*');
      for (const key of redisKeys) {
        const ttl = await this.redis.ttl(key);
        if (ttl <= 0) {
          await this.redis.del(key);
        }
      }
      
      // Очистка файловой системы
      await this.cleanupOldFiles();
      
      this.emit('cache:cleanup_completed');
      
    } catch (error) {
      this.logger.error('Error during cleanup:', error);
    }
  }

  // Метаданные
  async loadMetadata() {
    try {
      const metadataPath = path.join(this.config.cacheDir, 'cache_metadata.json');
      const data = await fs.readFile(metadataPath, 'utf8');
      const metadata = JSON.parse(data);
      
      this.stats = {
        ...this.stats,
        ...metadata.stats
      };
      
      this.fileSizes = new Map(Object.entries(metadata.fileSizes || {}));
      
    } catch (error) {
      if (error.code !== 'ENOENT') {
        this.logger.error('Error loading cache metadata:', error);
      }
    }
  }

  async saveMetadata() {
    try {
      const metadataPath = path.join(this.config.cacheDir, 'cache_metadata.json');
      const metadata = {
        stats: this.stats,
        fileSizes: Object.fromEntries(this.fileSizes),
        timestamp: Date.now()
      };
      
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
      
    } catch (error) {
      this.logger.error('Error saving cache metadata:', error);
    }
  }

  // Получение статистики
  async getStats() {
    return {
      ...this.stats,
      memoryCacheSize: this.memoryCache.size,
      accessLogSize: this.accessLog.size,
      fileSizesCount: this.fileSizes.size
    };
  }

  async getCacheInfo(key) {
    const cacheKey = this.generateCacheKey(key);
    
    const info = {
      key: cacheKey,
      exists: false,
      sources: []
    };
    
    // Проверка в памяти
    if (this.memoryCache.has(cacheKey)) {
      const entry = this.memoryCache.get(cacheKey);
      info.sources.push({
        location: 'memory',
        size: entry.size,
        timestamp: entry.timestamp,
        expired: this.isExpired(entry)
      });
      info.exists = true;
    }
    
    // Проверка в Redis
    try {
      const redisData = await this.redis.get(`cache:${cacheKey}`);
      if (redisData) {
        const entry = JSON.parse(redisData);
        info.sources.push({
          location: 'redis',
          size: entry.size,
          timestamp: entry.timestamp,
          expired: this.isExpired(entry)
        });
        info.exists = true;
      }
    } catch (error) {
      // Игнорируем ошибки
    }
    
    // Проверка в файловой системе
    const filePath = this.getFilePath(cacheKey);
    try {
      const stats = await fs.stat(filePath);
      const data = await fs.readFile(filePath);
      const entry = JSON.parse(data);
      
      info.sources.push({
        location: 'filesystem',
        size: stats.size,
        timestamp: entry.timestamp,
        expired: this.isExpired(entry)
      });
      info.exists = true;
    } catch (error) {
      // Игнорируем ошибки
    }
    
    return info;
  }

  // Очистка
  async clear() {
    try {
      // Очистка памяти
      this.memoryCache.clear();
      
      // Очистка Redis
      const keys = await this.redis.keys('cache:*');
      if (keys.length > 0) {
        await this.redis.del(...keys);
      }
      
      // Очистка файлов
      const files = await fs.readdir(this.config.cacheDir);
      for (const file of files) {
        if (file.endsWith('.cache')) {
          await fs.unlink(path.join(this.config.cacheDir, file));
        }
      }
      
      // Сброс статистики
      this.stats = {
        hits: 0,
        misses: 0,
        evictions: 0,
        totalSize: 0,
        fileCount: 0
      };
      
      this.accessLog.clear();
      this.fileSizes.clear();
      
      this.emit('cache:cleared');
      
    } catch (error) {
      this.logger.error('Error clearing cache:', error);
    }
  }

  // Очистка при завершении
  async shutdown() {
    this.logger.info('CacheManager shutting down...');
    
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
    }
    
    if (this.statsTimer) {
      clearInterval(this.statsTimer);
    }
    
    await this.saveMetadata();
    
    this.logger.info('CacheManager shut down');
  }
}

module.exports = CacheManager;