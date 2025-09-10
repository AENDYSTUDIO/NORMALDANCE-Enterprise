// Критические метрики для мониторинга производительности
export class PerformanceMonitor {
  private metrics = new Map<string, number[]>()
  
  // Отслеживание времени загрузки аудио
  trackAudioLoadTime(trackId: string, loadTime: number) {
    const key = `audio_load_${trackId}`
    if (!this.metrics.has(key)) this.metrics.set(key, [])
    this.metrics.get(key)!.push(loadTime)
    
    // Цель: < 2 секунды (текущий ~3 секунды)
    if (loadTime > 2000) {
      console.warn(`Slow audio load: ${trackId} took ${loadTime}ms`)
    }
  }
  
  // Отслеживание API ответов
  trackAPIResponse(endpoint: string, responseTime: number) {
    const key = `api_${endpoint}`
    if (!this.metrics.has(key)) this.metrics.set(key, [])
    this.metrics.get(key)!.push(responseTime)
    
    // Цель: < 200ms (текущий ~350ms)
    if (responseTime > 200) {
      console.warn(`Slow API response: ${endpoint} took ${responseTime}ms`)
    }
  }
  
  // Отслеживание пользовательских сессий
  trackUserSession(duration: number) {
    if (!this.metrics.has('session_duration')) this.metrics.set('session_duration', [])
    this.metrics.get('session_duration')!.push(duration)
    
    // Цель: 12 минут (текущий ~8 минут)
    console.log(`Session duration: ${duration / 60000} minutes`)
  }
  
  getMetrics() {
    const result: Record<string, { avg: number; max: number; count: number }> = {}
    
    for (const [key, values] of this.metrics) {
      result[key] = {
        avg: values.reduce((a, b) => a + b, 0) / values.length,
        max: Math.max(...values),
        count: values.length
      }
    }
    
    return result
  }
}

export const performanceMonitor = new PerformanceMonitor()