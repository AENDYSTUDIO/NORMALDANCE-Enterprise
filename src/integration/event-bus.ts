// Event-driven architecture
import Redis from 'ioredis'

interface Event {
  type: string
  payload: any
  timestamp: number
  source: string
}

export class EventBus {
  private redis: Redis
  private subscribers = new Map<string, Function[]>()

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL!)
  }

  async publish(event: Event): Promise<void> {
    await this.redis.publish('events', JSON.stringify(event))
  }

  subscribe(eventType: string, handler: Function): void {
    if (!this.subscribers.has(eventType)) {
      this.subscribers.set(eventType, [])
    }
    this.subscribers.get(eventType)!.push(handler)
  }

  async listen(): Promise<void> {
    const subscriber = new Redis(process.env.REDIS_URL!)
    await subscriber.subscribe('events')
    
    subscriber.on('message', (channel, message) => {
      const event: Event = JSON.parse(message)
      const handlers = this.subscribers.get(event.type) || []
      handlers.forEach(handler => handler(event))
    })
  }
}

// Event types
export const Events = {
  USER_REGISTERED: 'user.registered',
  TRACK_UPLOADED: 'track.uploaded',
  NFT_MINTED: 'nft.minted',
  PAYMENT_PROCESSED: 'payment.processed'
} as const

export const eventBus = new EventBus()