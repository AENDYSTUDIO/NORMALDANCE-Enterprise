// Enterprise API Gateway
import express from 'express'
import { createProxyMiddleware } from 'http-proxy-middleware'
import { rateLimit } from 'express-rate-limit'

const app = express()

// Service registry
const services = {
  users: 'http://user-service:3001',
  tracks: 'http://track-service:3002', 
  nft: 'http://nft-service:3003',
  payments: 'http://payment-service:3004'
}

// Global middleware
app.use(express.json())
app.use(rateLimit({ windowMs: 60000, max: 1000 }))

// Service proxies
Object.entries(services).forEach(([name, url]) => {
  app.use(`/api/${name}`, createProxyMiddleware({
    target: url,
    changeOrigin: true,
    pathRewrite: { [`^/api/${name}`]: '' }
  }))
})

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', services: Object.keys(services) })
})

export default app