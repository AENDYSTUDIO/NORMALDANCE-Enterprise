import { rateLimit } from 'express-rate-limit'
import { RedisStore } from 'rate-limit-redis'
import Redis from 'ioredis'

const redis = new Redis(process.env.REDIS_URL!)

// Adaptive rate limiting
export const adaptiveLimit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 60 * 1000,
  max: async (req) => {
    const ip = req.ip
    const suspiciousCount = await redis.get(`suspicious:${ip}`) || 0
    return suspiciousCount > 5 ? 1 : 100 // Aggressive limiting for suspicious IPs
  },
  keyGenerator: (req) => req.ip,
  onLimitReached: async (req) => {
    await redis.incr(`suspicious:${req.ip}`)
    await redis.expire(`suspicious:${req.ip}`, 3600)
  }
})

// Geographic rate limiting
export const geoLimit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 60 * 1000,
  max: (req) => {
    const country = req.headers['cf-ipcountry'] || 'unknown'
    const highRiskCountries = ['CN', 'RU', 'KP']
    return highRiskCountries.includes(country) ? 10 : 100
  }
})

// Behavioral analysis
export const behaviorLimit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 300 * 1000, // 5 min
  max: async (req) => {
    const pattern = await analyzeRequestPattern(req.ip)
    return pattern.isBot ? 5 : 500
  }
})

async function analyzeRequestPattern(ip: string) {
  const requests = await redis.lrange(`pattern:${ip}`, 0, -1)
  const intervals = requests.map((r, i) => i > 0 ? parseInt(r) - parseInt(requests[i-1]) : 0)
  const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length
  
  return {
    isBot: avgInterval < 100, // Less than 100ms between requests
    score: avgInterval
  }
}