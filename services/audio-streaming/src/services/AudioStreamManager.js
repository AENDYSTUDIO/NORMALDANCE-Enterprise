const EventEmitter = require('events');
const fs = require('fs').promises;
const path = require('path');
const { PassThrough } = require('stream');
const ffmpeg = require('fluent-ffmpeg');
const crypto = require('crypto');

class AudioStreamManager extends EventEmitter {
  constructor(logger, metricsCollector, cacheManager, adaptiveBitrate) {
    super();
    this.logger = logger;
    this.metrics = metricsCollector;
    this.cache = cacheManager;
    this.adaptive = adaptiveBitrate;
    
    // Конфигурация
    this.config = {
      segmentDuration: 4, // 4 секунды
      maxSegmentSize: 1024 * 1024 * 2, // 2MB
      maxConcurrentStreams: 100,
      maxConnectionsPerUser: 3,
      
      // Параметры кодирования
      encoding: {
        audioCodec: 'aac',
        audioBitrate: '128k',
        audioChannels: 2,
        sampleRate: 44100,
        format: 'mp4',
        movflags: 'frag_keyframe+empty_moov'
      },
      
      // Качество
      qualities: {
        '64kbps': { bitrate: '64k', sampleRate: 22050 },
        '96kbps': { bitrate: '96k', sampleRate: 44100 },
        '128kbps': { bitrate: '128k', sampleRate: 44100 },
        '192kbps': { bitrate: '192k', sampleRate: 44100 },
        '320kbps': { bitrate: '320k', sampleRate: 44100 }
      },
      
      // Буферизация
      buffer: {
        preBuffer: 2, // предзагрузка 2 сегмента
        maxBuffer: 10, // максимум 10 сегментов
        minBuffer: 1 // минимум 1 сегмент
      },
      
      // Ограничения
      limits: {
        maxBitrate: 320000,
        maxFileSize: 100 * 1024 * 1024, // 100MB
        maxDuration: 3600 // 1 час
      }
    };
    
    // Состояние
    this.activeStreams = new Map();
    this.userConnections = new Map();
    this.segmentCache = new Map();
    this.processingQueue = [];
    
    // Метрики
    this.metrics = {
      totalStreams: 0,
      activeStreams: 0,
      totalSegments: 0,
      totalBytes: 0,
      averageBitrate: 0,
      errors: 0
    };
    
    this.initialize();
  }

  async initialize() {
    this.logger.info('AudioStreamManager initializing...');
    
    // Создание директорий
    await this.ensureDirectories();
    
    // Запуск периодических задач
    this.startPeriodicTasks();
    
    this.logger.info('AudioStreamManager initialized');
  }

  async ensureDirectories() {
    const dirs = [
      './streams',
      './streams/temp',
      './streams/segments',
      './streams/cache'
    ];
    
    for (const dir of dirs) {
      try {
        await fs.mkdir(dir, { recursive: true });
      } catch (error) {
        this.logger.error(`Error creating directory ${dir}:`, error);
      }
    }
  }

  // Основные методы потоковой передачи
  async createStream(userId, trackId, options = {}) {
    const streamId = this.generateStreamId(userId, trackId);
    const quality = options.quality || '128kbps';
    
    // Проверка ограничений
    if (!this.canCreateStream(userId)) {
      throw new Error('Stream limit exceeded');
    }
    
    // Проверка качества
    if (!this.config.qualities[quality]) {
      throw new Error(`Invalid quality: ${quality}`);
    }
    
    const stream = {
      id: streamId,
      userId,
      trackId,
      quality,
      startTime: Date.now(),
      segments: [],
      currentSegment: 0,
      totalSegments: 0,
      bytesSent: 0,
      status: 'initializing',
      options
    };
    
    this.activeStreams.set(streamId, stream);
    this.addUserConnection(userId, streamId);
    
    // Инициализация пользователя в adaptive bitrate
    await this.adaptive.registerUser(userId, quality);
    
    this.metrics.totalStreams++;
    this.metrics.activeStreams = this.activeStreams.size;
    
    this.emit('stream:created', { streamId, userId, trackId, quality });
    
    return streamId;
  }

  async startStream(streamId) {
    const stream = this.activeStreams.get(streamId);
    if (!stream) {
      throw new Error(`Stream ${streamId} not found`);
    }
    
    try {
      // Получение информации о треке
      const trackInfo = await this.getTrackInfo(stream.trackId);
      if (!trackInfo) {
        throw new Error(`Track ${stream.trackId} not found`);
      }
      
      stream.trackInfo = trackInfo;
      stream.totalSegments = Math.ceil(trackInfo.duration / this.config.segmentDuration);
      
      // Подготовка сегментов
      await this.prepareSegments(stream);
      
      stream.status = 'active';
      
      this.emit('stream:started', { streamId, trackInfo });
      
      return stream;
      
    } catch (error) {
      stream.status = 'error';
      this.logger.error('Error starting stream:', error);
      throw error;
    }
  }

  async getSegment(streamId, segmentNumber) {
    const stream = this.activeStreams.get(streamId);
    if (!stream) {
      throw new Error(`Stream ${streamId} not found`);
    }
    
    if (segmentNumber < 0 || segmentNumber >= stream.totalSegments) {
      throw new Error(`Invalid segment number: ${segmentNumber}`);
    }
    
    const cacheKey = this.generateSegmentKey(stream.trackId, stream.quality, segmentNumber);
    
    // Проверка кэша
    const cachedSegment = await this.cache.get(cacheKey);
    if (cachedSegment) {
      this.emit('segment:cache_hit', { streamId, segmentNumber });
      return cachedSegment;
    }
    
    // Генерация сегмента
    const segment = await this.generateSegment(stream, segmentNumber);
    
    // Кэширование
    await this.cache.set(cacheKey, segment, {
      ttl: 3600,
      compress: true
    });
    
    this.metrics.totalSegments++;
    this.metrics.totalBytes += segment.length;
    
    this.emit('segment:generated', { streamId, segmentNumber });
    
    return segment;
  }

  async generateSegment(stream, segmentNumber) {
    const startTime = segmentNumber * this.config.segmentDuration;
    const duration = Math.min(
      this.config.segmentDuration,
      stream.trackInfo.duration - startTime
    );
    
    const qualityConfig = this.config.qualities[stream.quality];
    
    return new Promise((resolve, reject) => {
      const chunks = [];
      
      const command = ffmpeg(stream.trackInfo.path)
        .setStartTime(startTime)
        .setDuration(duration)
        .audioCodec(this.config.encoding.audioCodec)
        .audioBitrate(qualityConfig.bitrate)
        .audioFrequency(qualityConfig.sampleRate)
        .audioChannels(this.config.encoding.audioChannels)
        .format(this.config.encoding.format)
        .addOutputOptions([
          `-movflags ${this.config.encoding.movflags}`,
          '-avoid_negative_ts make_zero',
          '-fflags +genpts'
        ])
        .on('error', (error) => {
          this.logger.error('FFmpeg error:', error);
          reject(error);
        })
        .on('end', () => {
          const buffer = Buffer.concat(chunks);
          resolve(buffer);
        });
      
      const streamOutput = new PassThrough();
      command.pipe(streamOutput);
      
      streamOutput.on('data', (chunk) => {
        chunks.push(chunk);
      });
    });
  }

  // Управление качеством
  async adaptQuality(streamId, newQuality) {
    const stream = this.activeStreams.get(streamId);
    if (!stream) {
      throw new Error(`Stream ${streamId} not found`);
    }
    
    if (!this.config.qualities[newQuality]) {
      throw new Error(`Invalid quality: ${newQuality}`);
    }
    
    const oldQuality = stream.quality;
    stream.quality = newQuality;
    
    // Очистка кэша сегментов для нового качества
    this.clearSegmentCache(stream.trackId, oldQuality);
    
    this.emit('quality:adapted', {
      streamId,
      userId: stream.userId,
      oldQuality,
      newQuality
    });
    
    return { oldQuality, newQuality };
  }

  // Потоковая передача
  async createReadableStream(streamId, startSegment = 0) {
    const stream = this.activeStreams.get(streamId);
    if (!stream) {
      throw new Error(`Stream ${streamId} not found`);
    }
    
    const readable = new PassThrough();
    
    // Запуск потоковой передачи
    this.streamSegments(stream, readable, startSegment);
    
    return readable;
  }

  async streamSegments(stream, output, startSegment) {
    let currentSegment = startSegment;
    
    const sendNextSegment = async () => {
      if (currentSegment >= stream.totalSegments) {
        output.end();
        return;
      }
      
      try {
        // Проверка адаптивного качества
        const recommendedQuality = await this.adaptive.getQualityRecommendation(stream.userId);
        if (recommendedQuality !== stream.quality) {
          await this.adaptQuality(stream.id, recommendedQuality);
        }
        
        // Получение сегмента
        const segment = await this.getSegment(stream.id, currentSegment);
        
        // Отправка сегмента
        output.write(segment);
        
        stream.currentSegment = currentSegment;
        stream.bytesSent += segment.length;
        
        currentSegment++;
        
        // Планирование следующего сегмента
        setTimeout(sendNextSegment, this.config.segmentDuration * 1000);
        
      } catch (error) {
        this.logger.error('Error streaming segment:', error);
        output.destroy(error);
      }
    };
    
    sendNextSegment();
  }

  // Управление соединениями
  canCreateStream(userId) {
    const userConnections = this.userConnections.get(userId) || [];
    return userConnections.length < this.config.maxConnectionsPerUser &&
           this.activeStreams.size < this.config.maxConcurrentStreams;
  }

  addUserConnection(userId, streamId) {
    if (!this.userConnections.has(userId)) {
      this.userConnections.set(userId, []);
    }
    
    const connections = this.userConnections.get(userId);
    connections.push(streamId);
  }

  removeUserConnection(userId, streamId) {
    if (this.userConnections.has(userId)) {
      const connections = this.userConnections.get(userId);
      const index = connections.indexOf(streamId);
      if (index > -1) {
        connections.splice(index, 1);
      }
      
      if (connections.length === 0) {
        this.userConnections.delete(userId);
      }
    }
  }

  // Вспомогательные методы
  async getTrackInfo(trackId) {
    // Заглушка - в реальном приложении это будет обращение к базе данных
    const mockTracks = {
      'track1': {
        id: 'track1',
        title: 'Test Track 1',
        artist: 'Test Artist',
        duration: 180,
        path: './test-audio/test.mp3',
        format: 'mp3',
        bitrate: 320000
      },
      'track2': {
        id: 'track2',
        title: 'Test Track 2',
        artist: 'Test Artist',
        duration: 240,
        path: './test-audio/test2.mp3',
        format: 'mp3',
        bitrate: 256000
      }
    };
    
    return mockTracks[trackId] || null;
  }

  generateStreamId(userId, trackId) {
    return `${userId}_${trackId}_${Date.now()}`;
  }

  generateSegmentKey(trackId, quality, segmentNumber) {
    return `segment_${trackId}_${quality}_${segmentNumber}`;
  }

  clearSegmentCache(trackId, quality) {
    // Очистка кэша сегментов для конкретного трека и качества
    const prefix = `segment_${trackId}_${quality}_`;
    // Реализация зависит от API кэша
  }

  // Периодические задачи
  startPeriodicTasks() {
    // Очистка неактивных потоков
    setInterval(() => {
      this.cleanupInactiveStreams();
    }, 30000); // Каждые 30 секунд
    
    // Обновление метрик
    setInterval(() => {
      this.updateMetrics();
    }, 10000); // Каждые 10 секунд
  }

  async cleanupInactiveStreams() {
    const now = Date.now();
    const inactiveThreshold = 5 * 60 * 1000; // 5 минут
    
    for (const [streamId, stream] of this.activeStreams.entries()) {
      if (now - stream.startTime > inactiveThreshold) {
        await this.stopStream(streamId);
      }
    }
  }

  async updateMetrics() {
    const totalBytes = Array.from(this.activeStreams.values())
      .reduce((sum, stream) => sum + stream.bytesSent, 0);
    
    this.metrics.totalBytes = totalBytes;
    this.metrics.averageBitrate = totalBytes > 0 
      ? (totalBytes * 8) / (this.metrics.totalSegments * this.config.segmentDuration)
      : 0;
    
    this.emit('metrics:updated', this.metrics);
  }

  // Остановка потока
  async stopStream(streamId) {
    const stream = this.activeStreams.get(streamId);
    if (!stream) {
      return;
    }
    
    stream.status = 'stopped';
    
    this.activeStreams.delete(streamId);
    this.removeUserConnection(stream.userId, streamId);
    
    // Отмена регистрации в adaptive bitrate
    await this.adaptive.unregisterUser(stream.userId);
    
    this.metrics.activeStreams = this.activeStreams.size;
    
    this.emit('stream:stopped', { streamId, userId: stream.userId });
  }

  // Получение статистики
  async getStreamStats(streamId) {
    const stream = this.activeStreams.get(streamId);
    if (!stream) {
      return null;
    }
    
    return {
      id: stream.id,
      userId: stream.userId,
      trackId: stream.trackId,
      quality: stream.quality,
      startTime: stream.startTime,
      currentSegment: stream.currentSegment,
      totalSegments: stream.totalSegments,
      bytesSent: stream.bytesSent,
      status: stream.status,
      progress: (stream.currentSegment / stream.totalSegments) * 100
    };
  }

  async getGlobalStats() {
    const activeStreams = Array.from(this.activeStreams.values());
    
    return {
      ...this.metrics,
      activeStreams: activeStreams.length,
      streamsByQuality: activeStreams.reduce((acc, stream) => {
        acc[stream.quality] = (acc[stream.quality] || 0) + 1;
        return acc;
      }, {}),
      usersByQuality: activeStreams.reduce((acc, stream) => {
        if (!acc[stream.userId]) {
          acc[stream.userId] = stream.quality;
        }
        return acc;
      }, {})
    };
  }

  // Очистка при завершении
  async shutdown() {
    this.logger.info('AudioStreamManager shutting down...');
    
    // Остановка всех активных потоков
    for (const streamId of this.activeStreams.keys()) {
      await this.stopStream(streamId);
    }
    
    this.logger.info('AudioStreamManager shut down');
  }
}

module.exports = AudioStreamManager;