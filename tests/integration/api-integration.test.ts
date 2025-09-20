import { describe, it, expect, beforeAll, afterAll } from '@jest/globals'
import request from 'supertest'
import app from '../../src/integration/api-gateway'

describe('API Integration Tests', () => {
  let server: any

  beforeAll(async () => {
    server = app.listen(0)
  })

  afterAll(async () => {
    await server.close()
  })

  describe('API Gateway', () => {
    it('should route to user service', async () => {
      const response = await request(app)
        .get('/api/users/health')
        .expect(200)
      
      expect(response.body).toHaveProperty('status')
    })

    it('should apply rate limiting', async () => {
      // Make multiple requests to trigger rate limit
      const requests = Array(1001).fill(null).map(() => 
        request(app).get('/health')
      )
      
      const responses = await Promise.allSettled(requests)
      const rateLimited = responses.some(r => 
        r.status === 'fulfilled' && r.value.status === 429
      )
      
      expect(rateLimited).toBe(true)
    })

    it('should handle service failures gracefully', async () => {
      const response = await request(app)
        .get('/api/nonexistent/test')
        .expect(502)
      
      expect(response.body).toHaveProperty('error')
    })
  })

  describe('Event Bus Integration', () => {
    it('should publish and receive events', async () => {
      const { eventBus, Events } = await import('../../src/integration/event-bus')
      
      let receivedEvent: any = null
      eventBus.subscribe(Events.USER_REGISTERED, (event: any) => {
        receivedEvent = event
      })

      await eventBus.publish({
        type: Events.USER_REGISTERED,
        payload: { userId: '123' },
        timestamp: Date.now(),
        source: 'test'
      })

      // Wait for event processing
      await new Promise(resolve => setTimeout(resolve, 100))
      
      expect(receivedEvent).toBeTruthy()
      expect(receivedEvent.payload.userId).toBe('123')
    })
  })

  describe('Data Pipeline Integration', () => {
    it('should extract, transform, and load data', async () => {
      const { dataPipeline } = await import('../../src/integration/data-pipeline')
      
      const mockData = [
        { id: 1, email: 'test@example.com', createdAt: '2024-01-01' }
      ]
      
      const transformed = await dataPipeline.transform(mockData, {
        anonymize: true,
        normalize: true
      })
      
      expect(transformed[0].email).toMatch(/te\*\*\*@example\.com/)
      expect(transformed[0].createdAt).toMatch(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    })
  })
})