import { rateLimit } from 'express-rate-limit'
import { RedisStore } from 'rate-limit-redis'
import Redis from 'ioredis'

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379')

// Global rate limiter
export const globalLimit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 15 * 60 * 1000, // 15 min
  max: 1000,
  message: { error: 'Too many requests' }
})

// Auth rate limiter
export const authLimit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 15 * 60 * 1000,
  max: 5,
  keyGenerator: (req) => `auth:${req.ip}:${req.body?.email || 'unknown'}`
})

// API rate limiter
export const apiLimit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 60 * 1000,
  max: (req) => req.user ? 100 : 20,
  keyGenerator: (req) => req.user?.id || req.ip
})

// Web3 rate limiter
export const web3Limit = rateLimit({
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) }),
  windowMs: 60 * 1000,
  max: 10,
  keyGenerator: (req) => `web3:${req.user?.walletAddress || req.ip}`
})