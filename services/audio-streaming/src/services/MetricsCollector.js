const EventEmitter = require('events');

class MetricsCollector extends EventEmitter {
  constructor(redisClient, logger, config = {}) {
    super();
    this.redis = redisClient;
    this.logger = logger;
    
    // Конфигурация
    this.config = {
      retentionPeriod: 3600, // 1 час
      aggregationInterval: 60000, // 1 минута
      enableRealtime: true,
      enableAggregation: true,
      metricsPrefix: 'metrics',
      ...config
    };
    
    // Временные хранилища
    this.realtimeMetrics = new Map();
    this.aggregatedMetrics = new Map();
    
    // Счетчики
    this.counters = new Map();
    this.timers = new Map();
    
    // Таймеры
    this.aggregationTimer = null;
    this.cleanupTimer = null;
    
    this.initialize();
  }

  async initialize() {
    this.logger.info('MetricsCollector initializing...');
    
    // Загрузка сохраненных метрик
    await this.loadMetrics();
    
    // Запуск периодических задач
    this.startPeriodicTasks();
    
    this.logger.info('MetricsCollector initialized');
  }

  // Основные методы сбора метрик
  recordStreamStart(userId, trackId, quality) {
    const timestamp = Date.now();
    const metric = {
      type: 'stream_start',
      userId,
      trackId,
      quality,
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    this.incrementCounter('total_streams');
    this.incrementCounter(`quality_${quality}`);
    
    this.emit('metric:stream_start', metric);
  }

  recordStreamEnd(userId, trackId, duration, quality) {
    const timestamp = Date.now();
    const metric = {
      type: 'stream_end',
      userId,
      trackId,
      quality,
      duration,
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    this.incrementCounter('total_stream_duration', duration);
    this.incrementCounter(`quality_${quality}_duration`, duration);
    
    this.emit('metric:stream_end', metric);
  }

  recordQualitySwitch(userId, fromQuality, toQuality, reason) {
    const timestamp = Date.now();
    const metric = {
      type: 'quality_switch',
      userId,
      fromQuality,
      toQuality,
      reason,
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    this.incrementCounter('quality_switches');
    this.incrementCounter(`switch_${fromQuality}_to_${toQuality}`);
    
    this.emit('metric:quality_switch', metric);
  }

  recordBufferEvent(userId, bufferLevel, eventType) {
    const timestamp = Date.now();
    const metric = {
      type: 'buffer_event',
      userId,
      bufferLevel,
      eventType, // 'buffering_start', 'buffering_end', 'buffer_low'
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    this.incrementCounter(`buffer_${eventType}`);
    
    this.emit('metric:buffer_event', metric);
  }

  recordError(userId, errorType, errorMessage, context = {}) {
    const timestamp = Date.now();
    const metric = {
      type: 'error',
      userId,
      errorType,
      errorMessage,
      context,
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    this.incrementCounter('errors');
    this.incrementCounter(`error_${errorType}`);
    
    this.emit('metric:error', metric);
  }

  recordPerformance(userId, metricType, value, unit = 'ms') {
    const timestamp = Date.now();
    const metric = {
      type: 'performance',
      userId,
      metricType, // 'segment_load_time', 'initial_load_time', 'seek_time'
      value,
      unit,
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    
    // Сохранение в таймеры для агрегации
    const timerKey = `perf_${metricType}`;
    if (!this.timers.has(timerKey)) {
      this.timers.set(timerKey, []);
    }
    
    this.timers.get(timerKey).push({
      value,
      timestamp
    });
    
    this.emit('metric:performance', metric);
  }

  recordUserActivity(userId, activityType, metadata = {}) {
    const timestamp = Date.now();
    const metric = {
      type: 'user_activity',
      userId,
      activityType, // 'play', 'pause', 'seek', 'skip'
      metadata,
      timestamp,
      date: new Date(timestamp).toISOString()
    };
    
    this.storeMetric(metric);
    this.incrementCounter(`activity_${activityType}`);
    
    this.emit('metric:user_activity', metric);
  }

  // Методы хранения и агрегации
  storeMetric(metric) {
    const key = `${this.config.metricsPrefix}:${metric.type}`;
    
    // Реалтайм метрики
    if (this.config.enableRealtime) {
      if (!this.realtimeMetrics.has(key)) {
        this.realtimeMetrics.set(key, []);
      }
      
      this.realtimeMetrics.get(key).push(metric);
      
      // Ограничение размера
      const metrics = this.realtimeMetrics.get(key);
      if (metrics.length > 1000) {
        metrics.shift();
      }
    }
    
    // Сохранение в Redis
    this.redis.lpush(key, JSON.stringify(metric));
    this.redis.expire(key, this.config.retentionPeriod);
  }

  async aggregateMetrics() {
    const now = Date.now();
    const startTime = now - this.config.aggregationInterval;
    
    try {
      const aggregation = {
        timestamp: now,
        interval: this.config.aggregationInterval,
        metrics: {}
      };
      
      // Агрегация счетчиков
      for (const [counterName, value] of this.counters.entries()) {
        aggregation.metrics[counterName] = {
          type: 'counter',
          value,
          rate: value / (this.config.aggregationInterval / 1000)
        };
      }
      
      // Агрегация таймеров
      for (const [timerName, values] of this.timers.entries()) {
        const relevantValues = values.filter(v => v.timestamp >= startTime);
        
        if (relevantValues.length > 0) {
          const valuesOnly = relevantValues.map(v => v.value);
          const sorted = valuesOnly.sort((a, b) => a - b);
          
          aggregation.metrics[timerName] = {
            type: 'timer',
            count: relevantValues.length,
            min: sorted[0],
            max: sorted[sorted.length - 1],
            avg: valuesOnly.reduce((a, b) => a + b, 0) / valuesOnly.length,
            p50: sorted[Math.floor(sorted.length * 0.5)],
            p95: sorted[Math.floor(sorted.length * 0.95)],
            p99: sorted[Math.floor(sorted.length * 0.99)]
          };
        }
      }
      
      // Сохранение агрегированных метрик
      const key = `${this.config.metricsPrefix}:aggregated:${Math.floor(now / this.config.aggregationInterval)}`;
      await this.redis.setex(key, this.config.retentionPeriod * 2, JSON.stringify(aggregation));
      
      // Очистка старых данных
      this.cleanupOldData();
      
      // Сброс счетчиков
      this.counters.clear();
      this.timers.clear();
      
      this.emit('metrics:aggregated', aggregation);
      
    } catch (error) {
      this.logger.error('Error aggregating metrics:', error);
    }
  }

  // Методы получения метрик
  async getRealtimeMetrics(types = []) {
    const metrics = {};
    
    try {
      if (types.length === 0) {
        // Получить все типы метрик
        const keys = await this.redis.keys(`${this.config.metricsPrefix}:*`);
        types = keys.map(key => key.replace(`${this.config.metricsPrefix}:`, ''));
      }
      
      for (const type of types) {
        const key = `${this.config.metricsPrefix}:${type}`;
        const data = await this.redis.lrange(key, 0, 100);
        
        metrics[type] = data.map(item => JSON.parse(item));
      }
      
    } catch (error) {
      this.logger.error('Error getting realtime metrics:', error);
    }
    
    return metrics;
  }

  async getAggregatedMetrics(timeRange = 3600) {
    const metrics = [];
    
    try {
      const now = Date.now();
      const startTime = now - (timeRange * 1000);
      
      const keys = await this.redis.keys(`${this.config.metricsPrefix}:aggregated:*`);
      
      for (const key of keys) {
        const timestamp = parseInt(key.split(':').pop()) * this.config.aggregationInterval;
        
        if (timestamp >= startTime) {
          const data = await this.redis.get(key);
          if (data) {
            metrics.push(JSON.parse(data));
          }
        }
      }
      
    } catch (error) {
      this.logger.error('Error getting aggregated metrics:', error);
    }
    
    return metrics.sort((a, b) => a.timestamp - b.timestamp);
  }

  async getUserMetrics(userId, timeRange = 3600) {
    const metrics = {};
    
    try {
      const allMetrics = await this.getRealtimeMetrics();
      
      for (const [type, data] of Object.entries(allMetrics)) {
        metrics[type] = data.filter(metric => metric.userId === userId);
      }
      
    } catch (error) {
      this.logger.error('Error getting user metrics:', error);
    }
    
    return metrics;
  }

  async getDashboardMetrics() {
    const dashboard = {
      realtime: {},
      aggregated: {},
      trends: {}
    };
    
    try {
      // Реалтайм метрики
      const realtime = await this.getRealtimeMetrics([
        'stream_start',
        'stream_end',
        'quality_switch',
        'buffer_event',
        'error'
      ]);
      
      dashboard.realtime = {
        activeStreams: realtime.stream_start?.length - (realtime.stream_end?.length || 0) || 0,
        totalStreams: realtime.stream_start?.length || 0,
        qualitySwitches: realtime.quality_switch?.length || 0,
        bufferEvents: realtime.buffer_event?.length || 0,
        errors: realtime.error?.length || 0
      };
      
      // Агрегированные метрики за последний час
      const aggregated = await this.getAggregatedMetrics(3600);
      if (aggregated.length > 0) {
        const latest = aggregated[aggregated.length - 1];
        dashboard.aggregated = latest.metrics;
      }
      
      // Тренды
      dashboard.trends = this.calculateTrends(aggregated);
      
    } catch (error) {
      this.logger.error('Error getting dashboard metrics:', error);
    }
    
    return dashboard;
  }

  // Вспомогательные методы
  incrementCounter(counterName, value = 1) {
    if (!this.counters.has(counterName)) {
      this.counters.set(counterName, 0);
    }
    
    this.counters.set(counterName, this.counters.get(counterName) + value);
  }

  calculateTrends(aggregatedMetrics) {
    if (aggregatedMetrics.length < 2) {
      return {};
    }
    
    const trends = {};
    
    // Анализ трендов для каждой метрики
    const metricsToAnalyze = ['total_streams', 'quality_switches', 'errors'];
    
    for (const metricName of metricsToAnalyze) {
      const values = aggregatedMetrics.map(m => m.metrics[metricName]?.value || 0);
      
      if (values.length >= 2) {
        const first = values[0];
        const last = values[values.length - 1];
        const change = ((last - first) / first) * 100;
        
        trends[metricName] = {
          change,
          trend: change > 0 ? 'up' : change < 0 ? 'down' : 'stable',
          values
        };
      }
    }
    
    return trends;
  }

  async cleanupOldData() {
    const cutoff = Date.now() - (this.config.retentionPeriod * 1000);
    
    // Очистка realtime метрик
    for (const [key, metrics] of this.realtimeMetrics.entries()) {
      const filtered = metrics.filter(m => m.timestamp >= cutoff);
      this.realtimeMetrics.set(key, filtered);
    }
    
    // Очистка Redis
    try {
      const keys = await this.redis.keys(`${this.config.metricsPrefix}:*`);
      
      for (const key of keys) {
        if (!key.includes(':aggregated:')) {
          await this.redis.ltrim(key, 0, 999); // Оставляем последние 1000
        }
      }
      
    } catch (error) {
      this.logger.error('Error cleaning up old data:', error);
    }
  }

  async loadMetrics() {
    // Загрузка последних метрик из Redis
    try {
      const keys = await this.redis.keys(`${this.config.metricsPrefix}:*`);
      
      for (const key of keys) {
        if (!key.includes(':aggregated:')) {
          const type = key.replace(`${this.config.metricsPrefix}:`, '');
          const data = await this.redis.lrange(key, 0, 100);
          
          this.realtimeMetrics.set(type, data.map(item => JSON.parse(item)));
        }
      }
      
    } catch (error) {
      this.logger.error('Error loading metrics:', error);
    }
  }

  // Периодические задачи
  startPeriodicTasks() {
    if (this.config.enableAggregation) {
      this.aggregationTimer = setInterval(() => {
        this.aggregateMetrics();
      }, this.config.aggregationInterval);
    }
    
    this.cleanupTimer = setInterval(() => {
      this.cleanupOldData();
    }, 300000); // каждые 5 минут
  }

  // Методы для тестирования
  async clearAllMetrics() {
    try {
      const keys = await this.redis.keys(`${this.config.metricsPrefix}:*`);
      
      if (keys.length > 0) {
        await this.redis.del(...keys);
      }
      
      this.realtimeMetrics.clear();
      this.aggregatedMetrics.clear();
      this.counters.clear();
      this.timers.clear();
      
    } catch (error) {
      this.logger.error('Error clearing metrics:', error);
    }
  }

  async generateTestData() {
    const userIds = ['user1', 'user2', 'user3'];
    const trackIds = ['track1', 'track2', 'track3'];
    const qualities = ['64kbps', '128kbps', '192kbps', '320kbps'];
    
    for (let i = 0; i < 100; i++) {
      const userId = userIds[Math.floor(Math.random() * userIds.length)];
      const trackId = trackIds[Math.floor(Math.random() * trackIds.length)];
      const quality = qualities[Math.floor(Math.random() * qualities.length)];
      
      this.recordStreamStart(userId, trackId, quality);
      
      // Случайные события
      if (Math.random() > 0.7) {
        this.recordQualitySwitch(userId, quality, qualities[Math.floor(Math.random() * qualities.length)], 'test');
      }
      
      if (Math.random() > 0.9) {
        this.recordError(userId, 'network', 'Test error', { test: true });
      }
      
      // Производительность
      this.recordPerformance(userId, 'segment_load_time', Math.random() * 1000 + 100);
    }
  }

  // Очистка
  async shutdown() {
    this.logger.info('MetricsCollector shutting down...');
    
    if (this.aggregationTimer) {
      clearInterval(this.aggregationTimer);
    }
    
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
    }
    
    // Последняя агрегация
    if (this.config.enableAggregation) {
      await this.aggregateMetrics();
    }
    
    this.logger.info('MetricsCollector shut down');
  }
}

module.exports = MetricsCollector;