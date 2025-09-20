// Integration monitoring system
export class IntegrationMonitor {
  private metrics = new Map<string, number>()
  private alerts: string[] = []

  // Service health monitoring
  async checkServiceHealth(): Promise<Record<string, boolean>> {
    const services = ['users', 'tracks', 'nft', 'payments']
    const health: Record<string, boolean> = {}
    
    for (const service of services) {
      try {
        const response = await fetch(`http://${service}-service:3000/health`)
        health[service] = response.ok
      } catch {
        health[service] = false
        this.createAlert(`Service ${service} is down`)
      }
    }
    
    return health
  }

  // API performance monitoring
  trackAPIPerformance(endpoint: string, duration: number): void {
    const key = `api.${endpoint}.duration`
    this.metrics.set(key, duration)
    
    if (duration > 1000) { // > 1 second
      this.createAlert(`Slow API response: ${endpoint} took ${duration}ms`)
    }
  }

  // Data pipeline monitoring
  trackDataPipeline(pipeline: string, recordsProcessed: number, errors: number): void {
    this.metrics.set(`pipeline.${pipeline}.processed`, recordsProcessed)
    this.metrics.set(`pipeline.${pipeline}.errors`, errors)
    
    const errorRate = errors / recordsProcessed
    if (errorRate > 0.05) { // > 5% error rate
      this.createAlert(`High error rate in pipeline ${pipeline}: ${errorRate * 100}%`)
    }
  }

  // Integration point monitoring
  async monitorIntegrations(): Promise<void> {
    const integrations = [
      { name: 'solana', url: 'https://api.devnet.solana.com' },
      { name: 'ipfs', url: 'https://ipfs.io' },
      { name: 'stripe', url: 'https://api.stripe.com' }
    ]
    
    for (const integration of integrations) {
      try {
        const start = Date.now()
        await fetch(integration.url, { method: 'HEAD' })
        const duration = Date.now() - start
        
        this.trackAPIPerformance(integration.name, duration)
      } catch {
        this.createAlert(`External integration ${integration.name} is unreachable`)
      }
    }
  }

  private createAlert(message: string): void {
    this.alerts.push(`${new Date().toISOString()}: ${message}`)
    console.warn(`ALERT: ${message}`)
  }

  getMetrics(): Record<string, number> {
    return Object.fromEntries(this.metrics)
  }

  getAlerts(): string[] {
    return [...this.alerts]
  }

  clearAlerts(): void {
    this.alerts.length = 0
  }
}

export const integrationMonitor = new IntegrationMonitor()