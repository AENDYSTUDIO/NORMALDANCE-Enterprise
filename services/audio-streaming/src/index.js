const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');

// Импорт сервисов
const Logger = require('./utils/Logger');
const MetricsCollector = require('./services/MetricsCollector');
const CacheManager = require('./services/CacheManager');
const AdaptiveBitrate = require('./services/AdaptiveBitrate');
const AudioStreamManager = require('./services/AudioStreamManager');

class AudioStreamingServer {
  constructor() {
    this.app = express();
    this.server = http.createServer(this.app);
    this.io = socketIO(this.server, {
      cors: {
        origin: process.env.CORS_ORIGIN || "*",
        methods: ["GET", "POST"]
      }
    });
    
    this.logger = new Logger('AudioStreamingServer');
    this.metrics = new MetricsCollector(this.logger);
    this.cache = new CacheManager(this.logger, this.metrics);
    this.adaptive = new AdaptiveBitrate(this.logger, this.metrics, this.cache);
    this.streamManager = new AudioStreamManager(this.logger, this.metrics, this.cache, this.adaptive);
    
    this.config = {
      port: process.env.PORT || 3001,
      host: process.env.HOST || '0.0.0.0',
      environment: process.env.NODE_ENV || 'development',
      
      // Ограничения
      rateLimit: {
        windowMs: 15 * 60 * 1000, // 15 минут
        max: 1000 // максимум 1000 запросов
      },
      
      // Безопасность
      cors: {
        origin: process.env.CORS_ORIGIN || true,
        credentials: true
      }
    };
    
    this.setupMiddleware();
    this.setupRoutes();
    this.setupSocketHandlers();
    this.setupErrorHandling();
  }

  setupMiddleware() {
    // Безопасность
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "ws:", "wss:"],
          fontSrc: ["'self'"],
          objectSrc: ["'none'"],
          mediaSrc: ["'self'", "blob:"],
          frameSrc: ["'none'"]
        }
      }
    }));
    
    // CORS
    this.app.use(cors(this.config.cors));
    
    // Сжатие
    this.app.use(compression());
    
    // Логирование
    this.app.use(morgan('combined', {
      stream: {
        write: (message) => this.logger.info(message.trim())
      }
    }));
    
    // Rate limiting
    const limiter = rateLimit({
      windowMs: this.config.rateLimit.windowMs,
      max: this.config.rateLimit.max,
      message: 'Too many requests from this IP'
    });
    this.app.use(limiter);
    
    // Парсинг JSON
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: this.config.environment,
        version: process.env.npm_package_version || '1.0.0'
      });
    });
    
    // Метрики
    this.app.get('/metrics', async (req, res) => {
      try {
        const metrics = await this.metrics.getMetrics();
        res.json(metrics);
      } catch (error) {
        this.logger.error('Error getting metrics:', error);
        res.status(500).json({ error: 'Internal server error' });
      }
    });
    
    // Создание потока
    this.app.post('/api/stream/create', async (req, res) => {
      try {
        const { userId, trackId, quality } = req.body;
        
        if (!userId || !trackId) {
          return res.status(400).json({ 
            error: 'userId and trackId are required' 
          });
        }
        
        const streamId = await this.streamManager.createStream(userId, trackId, { quality });
        await this.streamManager.startStream(streamId);
        
        res.json({
          streamId,
          status: 'created',
          segmentDuration: this.streamManager.config.segmentDuration,
          totalSegments: this.streamManager.activeStreams.get(streamId).totalSegments
        });
        
      } catch (error) {
        this.logger.error('Error creating stream:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    // Получение сегмента
    this.app.get('/api/stream/:streamId/segment/:segmentNumber', async (req, res) => {
      try {
        const { streamId, segmentNumber } = req.params;
        const segmentNum = parseInt(segmentNumber);
        
        if (isNaN(segmentNum) || segmentNum < 0) {
          return res.status(400).json({ error: 'Invalid segment number' });
        }
        
        const segment = await this.streamManager.getSegment(streamId, segmentNum);
        
        res.set({
          'Content-Type': 'audio/mp4',
          'Content-Length': segment.length,
          'Cache-Control': 'public, max-age=3600',
          'ETag': `"${crypto.createHash('md5').update(segment).digest('hex')}"`
        });
        
        res.send(segment);
        
      } catch (error) {
        this.logger.error('Error getting segment:', error);
        res.status(404).json({ error: error.message });
      }
    });
    
    // Получение статистики потока
    this.app.get('/api/stream/:streamId/stats', async (req, res) => {
      try {
        const { streamId } = req.params;
        const stats = await this.streamManager.getStreamStats(streamId);
        
        if (!stats) {
          return res.status(404).json({ error: 'Stream not found' });
        }
        
        res.json(stats);
        
      } catch (error) {
        this.logger.error('Error getting stream stats:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    // Получение глобальной статистики
    this.app.get('/api/stats', async (req, res) => {
      try {
        const stats = await this.streamManager.getGlobalStats();
        res.json(stats);
        
      } catch (error) {
        this.logger.error('Error getting global stats:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    // Адаптивное качество
    this.app.post('/api/adaptive/update', async (req, res) => {
      try {
        const { userId, metrics } = req.body;
        
        if (!userId || !metrics) {
          return res.status(400).json({ 
            error: 'userId and metrics are required' 
          });
        }
        
        await this.adaptive.updateMetrics(userId, metrics);
        const recommendation = await this.adaptive.getQualityRecommendation(userId);
        
        res.json({
          recommendation,
          status: 'updated'
        });
        
      } catch (error) {
        this.logger.error('Error updating adaptive metrics:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    // Получение состояния адаптивного качества
    this.app.get('/api/adaptive/:userId/state', async (req, res) => {
      try {
        const { userId } = req.params;
        const state = await this.adaptive.getUserState(userId);
        
        if (!state) {
          return res.status(404).json({ error: 'User not found' });
        }
        
        res.json(state);
        
      } catch (error) {
        this.logger.error('Error getting adaptive state:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    // Статические файлы
    this.app.use('/static', express.static('public'));
    
    // 404 обработчик
    this.app.use((req, res) => {
      res.status(404).json({ error: 'Not found' });
    });
  }

  setupSocketHandlers() {
    this.io.on('connection', (socket) => {
      this.logger.info(`Client connected: ${socket.id}`);
      
      // Регистрация пользователя
      socket.on('register', async (data) => {
        try {
          const { userId } = data;
          if (userId) {
            socket.userId = userId;
            socket.join(`user_${userId}`);
            
            socket.emit('registered', { userId });
          }
        } catch (error) {
          this.logger.error('Error registering user:', error);
          socket.emit('error', { message: error.message });
        }
      });
      
      // Создание потока через WebSocket
      socket.on('createStream', async (data) => {
        try {
          const { trackId, quality } = data;
          
          if (!socket.userId) {
            socket.emit('error', { message: 'User not registered' });
            return;
          }
          
          const streamId = await this.streamManager.createStream(
            socket.userId, 
            trackId, 
            { quality }
          );
          
          await this.streamManager.startStream(streamId);
          
          socket.currentStream = streamId;
          socket.join(`stream_${streamId}`);
          
          socket.emit('streamCreated', {
            streamId,
            segmentDuration: this.streamManager.config.segmentDuration,
            totalSegments: this.streamManager.activeStreams.get(streamId).totalSegments
          });
          
        } catch (error) {
          this.logger.error('Error creating stream via WebSocket:', error);
          socket.emit('error', { message: error.message });
        }
      });
      
      // Запрос сегмента
      socket.on('getSegment', async (data) => {
        try {
          const { streamId, segmentNumber } = data;
          
          if (!socket.userId) {
            socket.emit('error', { message: 'User not registered' });
            return;
          }
          
          const segment = await this.streamManager.getSegment(streamId, segmentNumber);
          
          socket.emit('segment', {
            streamId,
            segmentNumber,
            data: segment.toString('base64'),
            size: segment.length
          });
          
        } catch (error) {
          this.logger.error('Error getting segment via WebSocket:', error);
          socket.emit('error', { message: error.message });
        }
      });
      
      // Обновление метрик
      socket.on('updateMetrics', async (data) => {
        try {
          const { metrics } = data;
          
          if (!socket.userId) {
            socket.emit('error', { message: 'User not registered' });
            return;
          }
          
          await this.adaptive.updateMetrics(socket.userId, metrics);
          const recommendation = await this.adaptive.getQualityRecommendation(socket.userId);
          
          socket.emit('qualityRecommendation', {
            recommendation,
            metrics
          });
          
        } catch (error) {
          this.logger.error('Error updating metrics via WebSocket:', error);
          socket.emit('error', { message: error.message });
        }
      });
      
      // Отключение
      socket.on('disconnect', () => {
        this.logger.info(`Client disconnected: ${socket.id}`);
        
        if (socket.currentStream) {
          this.streamManager.stopStream(socket.currentStream);
        }
      });
    });
    
    // Обработчики событий сервисов
    this.streamManager.on('stream:created', (data) => {
      this.io.to(`user_${data.userId}`).emit('streamEvent', data);
    });
    
    this.streamManager.on('stream:started', (data) => {
      this.io.to(`stream_${data.streamId}`).emit('streamStarted', data);
    });
    
    this.streamManager.on('stream:stopped', (data) => {
      this.io.to(`stream_${data.streamId}`).emit('streamStopped', data);
    });
    
    this.adaptive.on('quality:adapted', (data) => {
      this.io.to(`user_${data.userId}`).emit('qualityChanged', data);
    });
  }

  setupErrorHandling() {
    // Обработка ошибок
    this.app.use((error, req, res, next) => {
      this.logger.error('Unhandled error:', error);
      
      res.status(500).json({
        error: 'Internal server error',
        message: this.config.environment === 'development' ? error.message : 'Something went wrong'
      });
    });
    
    // Обработка необработанных исключений
    process.on('uncaughtException', (error) => {
      this.logger.error('Uncaught exception:', error);
      this.shutdown();
    });
    
    process.on('unhandledRejection', (reason, promise) => {
      this.logger.error('Unhandled rejection at:', promise, 'reason:', reason);
      this.shutdown();
    });
    
    // Graceful shutdown
    process.on('SIGTERM', () => {
      this.logger.info('SIGTERM received, shutting down gracefully...');
      this.shutdown();
    });
    
    process.on('SIGINT', () => {
      this.logger.info('SIGINT received, shutting down gracefully...');
      this.shutdown();
    });
  }

  async start() {
    try {
      this.logger.info('Starting Audio Streaming Server...');
      
      this.server.listen(this.config.port, this.config.host, () => {
        this.logger.info(`Server running on http://${this.config.host}:${this.config.port}`);
        this.logger.info(`Environment: ${this.config.environment}`);
      });
      
    } catch (error) {
      this.logger.error('Error starting server:', error);
      process.exit(1);
    }
  }

  async shutdown() {
    this.logger.info('Shutting down server...');
    
    // Закрытие сервера
    this.server.close(() => {
      this.logger.info('HTTP server closed');
    });
    
    // Остановка сервисов
    await this.streamManager.shutdown();
    await this.adaptive.shutdown();
    await this.cache.shutdown();
    
    this.logger.info('Server shut down complete');
    process.exit(0);
  }
}

// Запуск сервера
if (require.main === module) {
  const server = new AudioStreamingServer();
  server.start();
}

module.exports = AudioStreamingServer;