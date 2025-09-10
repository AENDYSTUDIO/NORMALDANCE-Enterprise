const EventEmitter = require('events');

class AdaptiveBitrate extends EventEmitter {
  constructor(logger, metricsCollector, cacheManager) {
    super();
    this.logger = logger;
    this.metrics = metricsCollector;
    this.cache = cacheManager;
    
    // Конфигурация
    this.config = {
      qualities: ['64kbps', '96kbps', '128kbps', '192kbps', '320kbps'],
      defaultQuality: '128kbps',
      minQuality: '64kbps',
      maxQuality: '320kbps',
      
      // Пороги для адаптации
      bandwidthThresholds: {
        '64kbps': 80 * 1024,    // 80 kbps
        '96kbps': 120 * 1024,   // 120 kbps
        '128kbps': 160 * 1024,  // 160 kbps
        '192kbps': 240 * 1024,  // 240 kbps
        '320kbps': 400 * 1024   // 400 kbps
      },
      
      // Параметры адаптации
      adaptation: {
        sampleWindow: 5000,     // 5 секунд
        minSamples: 3,          // минимум 3 измерения
        stabilityThreshold: 0.2, // 20% изменения
        cooldownPeriod: 10000,  // 10 секунд между изменениями
        aggressiveDowngrade: true,
        conservativeUpgrade: true
      },
      
      // Буферизация
      buffer: {
        minBuffer: 2,           // минимум 2 сегмента
        targetBuffer: 5,        // целевой буфер 5 сегментов
        maxBuffer: 10,          // максимум 10 сегментов
        emergencyBuffer: 1      // аварийный буфер
      }
    };
    
    // Состояние пользователей
    this.userStates = new Map();
    
    // Метрики
    this.metrics = {
      totalAdaptations: 0,
      qualityUpgrades: 0,
      qualityDowngrades: 0,
      bufferUnderruns: 0,
      bufferOverruns: 0
    };
    
    this.initialize();
  }

  async initialize() {
    this.logger.info('AdaptiveBitrate initializing...');
    
    // Запуск периодических задач
    this.startPeriodicTasks();
    
    this.logger.info('AdaptiveBitrate initialized');
  }

  // Управление состоянием пользователя
  async registerUser(userId, initialQuality = null) {
    const quality = initialQuality || this.config.defaultQuality;
    
    const userState = {
      userId,
      currentQuality: quality,
      bandwidthHistory: [],
      bufferLevel: 0,
      lastAdaptation: 0,
      adaptationHistory: [],
      segmentMetrics: [],
      connectionInfo: {
        type: 'unknown',
        effectiveType: 'unknown',
        downlink: 0,
        rtt: 0
      },
      preferences: {
        maxQuality: this.config.maxQuality,
        minQuality: this.config.minQuality,
        autoAdapt: true
      }
    };
    
    this.userStates.set(userId, userState);
    
    this.emit('user:registered', { userId, quality });
    
    return userState;
  }

  async unregisterUser(userId) {
    if (this.userStates.has(userId)) {
      this.userStates.delete(userId);
      this.emit('user:unregistered', { userId });
    }
  }

  // Обновление метрик
  async updateMetrics(userId, metrics) {
    const userState = this.userStates.get(userId);
    if (!userState) {
      this.logger.warn(`User ${userId} not found for metrics update`);
      return;
    }
    
    // Обновление истории пропускной способности
    if (metrics.bandwidth) {
      userState.bandwidthHistory.push({
        timestamp: Date.now(),
        bandwidth: metrics.bandwidth,
        latency: metrics.latency || 0
      });
      
      // Ограничение истории
      const cutoff = Date.now() - this.config.adaptation.sampleWindow;
      userState.bandwidthHistory = userState.bandwidthHistory.filter(
        entry => entry.timestamp > cutoff
      );
    }
    
    // Обновление уровня буфера
    if (metrics.bufferLevel !== undefined) {
      userState.bufferLevel = metrics.bufferLevel;
    }
    
    // Обновление информации о соединении
    if (metrics.connectionInfo) {
      userState.connectionInfo = {
        ...userState.connectionInfo,
        ...metrics.connectionInfo
      };
    }
    
    // Обновление метрик сегмента
    if (metrics.segment) {
      userState.segmentMetrics.push({
        ...metrics.segment,
        timestamp: Date.now()
      });
      
      // Ограничение истории
      if (userState.segmentMetrics.length > 50) {
        userState.segmentMetrics = userState.segmentMetrics.slice(-50);
      }
    }
    
    // Проверка необходимости адаптации
    if (userState.preferences.autoAdapt) {
      await this.checkAdaptation(userId);
    }
    
    this.emit('metrics:updated', { userId, metrics });
  }

  // Адаптивная логика
  async checkAdaptation(userId) {
    const userState = this.userStates.get(userId);
    if (!userState) return;
    
    const now = Date.now();
    
    // Проверка кулдауна
    if (now - userState.lastAdaptation < this.config.adaptation.cooldownPeriod) {
      return;
    }
    
    // Проверка достаточности данных
    if (userState.bandwidthHistory.length < this.config.adaptation.minSamples) {
      return;
    }
    
    // Расчет средней пропускной способности
    const avgBandwidth = this.calculateAverageBandwidth(userState.bandwidthHistory);
    
    // Определение нового качества
    const newQuality = this.determineQuality(
      avgBandwidth,
      userState.bufferLevel,
      userState.currentQuality,
      userState.preferences
    );
    
    if (newQuality !== userState.currentQuality) {
      await this.changeQuality(userId, newQuality, 'adaptive');
    }
  }

  calculateAverageBandwidth(history) {
    if (history.length === 0) return 0;
    
    // Используем экспоненциальное скользящее среднее
    const weights = history.map((_, index) => 
      Math.pow(0.8, history.length - 1 - index)
    );
    
    const weightedSum = history.reduce((sum, entry, index) => 
      sum + entry.bandwidth * weights[index], 0
    );
    
    const weightSum = weights.reduce((sum, weight) => sum + weight, 0);
    
    return weightedSum / weightSum;
  }

  determineQuality(avgBandwidth, bufferLevel, currentQuality, preferences) {
    const currentIndex = this.config.qualities.indexOf(currentQuality);
    const minIndex = this.config.qualities.indexOf(preferences.minQuality);
    const maxIndex = this.config.qualities.indexOf(preferences.maxQuality);
    
    // Проверка буфера
    if (bufferLevel <= this.config.buffer.emergencyBuffer) {
      // Аварийное понижение качества
      return this.config.qualities[minIndex];
    }
    
    if (bufferLevel >= this.config.buffer.maxBuffer) {
      // Буфер переполнен - возможно повышение
      const nextQuality = currentIndex + 1;
      if (nextQuality <= maxIndex) {
        const nextQualityName = this.config.qualities[nextQuality];
        const requiredBandwidth = this.config.bandwidthThresholds[nextQualityName];
        
        if (avgBandwidth >= requiredBandwidth * 1.2) {
          return nextQualityName;
        }
      }
    }
    
    // Обычная адаптация по пропускной способности
    let targetQuality = currentQuality;
    
    for (let i = this.config.qualities.length - 1; i >= 0; i--) {
      const quality = this.config.qualities[i];
      const threshold = this.config.bandwidthThresholds[quality];
      
      if (avgBandwidth >= threshold * 1.1) {
        targetQuality = quality;
        break;
      }
    }
    
    // Ограничение по предпочтениям
    const targetIndex = Math.max(
      minIndex,
      Math.min(maxIndex, this.config.qualities.indexOf(targetQuality))
    );
    
    return this.config.qualities[targetIndex];
  }

  async changeQuality(userId, newQuality, reason = 'manual') {
    const userState = this.userStates.get(userId);
    if (!userState) {
      throw new Error(`User ${userId} not found`);
    }
    
    const oldQuality = userState.currentQuality;
    
    if (oldQuality === newQuality) {
      return;
    }
    
    userState.currentQuality = newQuality;
    userState.lastAdaptation = Date.now();
    
    userState.adaptationHistory.push({
      timestamp: Date.now(),
      from: oldQuality,
      to: newQuality,
      reason
    });
    
    // Ограничение истории
    if (userState.adaptationHistory.length > 100) {
      userState.adaptationHistory = userState.adaptationHistory.slice(-100);
    }
    
    // Обновление метрик
    this.metrics.totalAdaptations++;
    if (this.config.qualities.indexOf(newQuality) > this.config.qualities.indexOf(oldQuality)) {
      this.metrics.qualityUpgrades++;
    } else {
      this.metrics.qualityDowngrades++;
    }
    
    this.emit('quality:changed', {
      userId,
      oldQuality,
      newQuality,
      reason,
      timestamp: Date.now()
    });
    
    return {
      oldQuality,
      newQuality,
      reason
    };
  }

  // Управление предпочтениями
  async setUserPreferences(userId, preferences) {
    const userState = this.userStates.get(userId);
    if (!userState) {
      throw new Error(`User ${userId} not found`);
    }
    
    userState.preferences = {
      ...userState.preferences,
      ...preferences
    };
    
    // Проверка текущего качества
    if (preferences.maxQuality || preferences.minQuality) {
      const currentIndex = this.config.qualities.indexOf(userState.currentQuality);
      const minIndex = this.config.qualities.indexOf(userState.preferences.minQuality);
      const maxIndex = this.config.qualities.indexOf(userState.preferences.maxQuality);
      
      if (currentIndex < minIndex) {
        await this.changeQuality(userId, userState.preferences.minQuality, 'preference');
      } else if (currentIndex > maxIndex) {
        await this.changeQuality(userId, userState.preferences.maxQuality, 'preference');
      }
    }
    
    this.emit('preferences:updated', { userId, preferences });
  }

  // Получение рекомендаций
  async getQualityRecommendation(userId) {
    const userState = this.userStates.get(userId);
    if (!userState) {
      return this.config.defaultQuality;
    }
    
    const avgBandwidth = this.calculateAverageBandwidth(userState.bandwidthHistory);
    const bufferLevel = userState.bufferLevel;
    
    return this.determineQuality(
      avgBandwidth,
      bufferLevel,
      userState.currentQuality,
      userState.preferences
    );
  }

  // Получение состояния
  async getUserState(userId) {
    const userState = this.userStates.get(userId);
    if (!userState) {
      return null;
    }
    
    return {
      userId: userState.userId,
      currentQuality: userState.currentQuality,
      bufferLevel: userState.bufferLevel,
      bandwidthHistory: userState.bandwidthHistory.slice(-10),
      adaptationHistory: userState.adaptationHistory.slice(-10),
      preferences: userState.preferences,
      connectionInfo: userState.connectionInfo
    };
  }

  // Получение статистики
  async getMetrics() {
    const userCount = this.userStates.size;
    const activeUsers = Array.from(this.userStates.keys());
    
    return {
      ...this.metrics,
      userCount,
      activeUsers,
      qualities: this.config.qualities
    };
  }

  // Симуляция для тестирования
  async simulateNetworkConditions(userId, conditions) {
    const userState = this.userStates.get(userId);
    if (!userState) {
      throw new Error(`User ${userId} not found`);
    }
    
    // Симуляция изменений пропускной способности
    if (conditions.bandwidth) {
      const bandwidthHistory = [];
      const now = Date.now();
      
      for (let i = 0; i < 10; i++) {
        bandwidthHistory.push({
          timestamp: now - (i * 1000),
          bandwidth: conditions.bandwidth * (0.8 + Math.random() * 0.4),
          latency: conditions.latency || 50
        });
      }
      
      userState.bandwidthHistory = bandwidthHistory;
    }
    
    // Симуляция уровня буфера
    if (conditions.bufferLevel !== undefined) {
      userState.bufferLevel = conditions.bufferLevel;
    }
    
    // Принудительная проверка адаптации
    await this.checkAdaptation(userId);
    
    this.emit('simulation:completed', { userId, conditions });
  }

  // Периодические задачи
  startPeriodicTasks() {
    // Очистка неактивных пользователей
    setInterval(() => {
      this.cleanupInactiveUsers();
    }, 300000); // Каждые 5 минут
    
    // Сбор метрик
    setInterval(() => {
      this.collectMetrics();
    }, 60000); // Каждую минуту
  }

  async cleanupInactiveUsers() {
    const now = Date.now();
    const inactiveThreshold = 10 * 60 * 1000; // 10 минут
    
    for (const [userId, userState] of this.userStates.entries()) {
      const lastActivity = Math.max(
        userState.lastAdaptation,
        userState.bandwidthHistory.length > 0 
          ? userState.bandwidthHistory[userState.bandwidthHistory.length - 1].timestamp 
          : 0
      );
      
      if (now - lastActivity > inactiveThreshold) {
        await this.unregisterUser(userId);
      }
    }
  }

  async collectMetrics() {
    const metrics = await this.getMetrics();
    
    this.emit('metrics:collected', metrics);
  }

  // Очистка при завершении
  async shutdown() {
    this.logger.info('AdaptiveBitrate shutting down...');
    
    // Сохранение состояния пользователей
    this.userStates.clear();
    
    this.logger.info('AdaptiveBitrate shut down');
  }
}

module.exports = AdaptiveBitrate;