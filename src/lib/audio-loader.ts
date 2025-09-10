// Оптимизированный загрузчик аудио с кэшированием
export class AudioLoader {
  private cache = new Map<string, ArrayBuffer>()
  private preloadQueue = new Set<string>()
  
  async loadAudio(url: string, priority: 'high' | 'low' = 'low'): Promise<ArrayBuffer> {
    if (this.cache.has(url)) {
      return this.cache.get(url)!
    }
    
    const response = await fetch(url)
    const buffer = await response.arrayBuffer()
    
    // Кэшируем только если файл < 50MB
    if (buffer.byteLength < 50 * 1024 * 1024) {
      this.cache.set(url, buffer)
    }
    
    return buffer
  }
  
  preloadNext(urls: string[]) {
    urls.slice(0, 3).forEach(url => {
      if (!this.preloadQueue.has(url)) {
        this.preloadQueue.add(url)
        this.loadAudio(url, 'low').catch(console.error)
      }
    })
  }
}