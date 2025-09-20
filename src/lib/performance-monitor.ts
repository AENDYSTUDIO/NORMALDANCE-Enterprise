class PerformanceMonitor {
  private metrics = new Map<string, number[]>()
  
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
  }
  
  measureAudioLatency(): void {
    if (typeof AudioContext !== 'undefined') {
      const audioContext = new AudioContext()
      setInterval(() => {
        const latency = audioContext.outputLatency || 0
        this.recordMetric('audio_latency', latency * 1000)
      }, 5000)
    }
  }
  
  private recordMetric(name: string, value: number): void {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, [])
    }
    
    const values = this.metrics.get(name)!
    values.push(value)
    
    if (values.length > 100) {
      values.shift()
    }
    
    // Alert on critical metrics
    if (this.isCritical(name, value)) {
      console.warn(`Critical performance metric: ${name} = ${value}`)
    }
  }
  
  private isCritical(name: string, value: number): boolean {
    const thresholds = {
      fcp: 2500,
      lcp: 4000,
      audio_latency: 150
    }
    return value > (thresholds[name as keyof typeof thresholds] || Infinity)
  }
  
  getStats() {
    const stats: Record<string, any> = {}
    for (const [name, values] of this.metrics) {
      stats[name] = {
        avg: values.reduce((a, b) => a + b, 0) / values.length,
        max: Math.max(...values),
        min: Math.min(...values)
      }
    }
    return stats
  }
}

export const performanceMonitor = new PerformanceMonitor()

// Auto-start monitoring
if (typeof window !== 'undefined') {
  performanceMonitor.measureWebVitals()
  performanceMonitor.measureAudioLatency()
}