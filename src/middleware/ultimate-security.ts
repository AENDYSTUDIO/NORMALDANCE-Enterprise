import { NextRequest, NextResponse } from 'next/server'
import crypto from 'crypto'

// Request signature validation
export function validateSignature(req: NextRequest) {
  const signature = req.headers.get('x-signature')
  const timestamp = req.headers.get('x-timestamp')
  const body = req.body
  
  if (!signature || !timestamp) {
    return false
  }
  
  const expectedSignature = crypto
    .createHmac('sha256', process.env.API_SECRET!)
    .update(timestamp + JSON.stringify(body))
    .digest('hex')
  
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  )
}

// Advanced input sanitization
export function sanitizeInput(input: any): any {
  if (typeof input === 'string') {
    return input
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '')
      .trim()
  }
  
  if (Array.isArray(input)) {
    return input.map(sanitizeInput)
  }
  
  if (typeof input === 'object' && input !== null) {
    const sanitized: any = {}
    for (const [key, value] of Object.entries(input)) {
      sanitized[sanitizeInput(key)] = sanitizeInput(value)
    }
    return sanitized
  }
  
  return input
}

// Request fingerprinting
export function generateFingerprint(req: NextRequest): string {
  const components = [
    req.headers.get('user-agent') || '',
    req.headers.get('accept-language') || '',
    req.headers.get('accept-encoding') || '',
    req.ip || ''
  ]
  
  return crypto
    .createHash('sha256')
    .update(components.join('|'))
    .digest('hex')
}

// Anomaly detection
const requestPatterns = new Map<string, number[]>()

export function detectAnomaly(fingerprint: string): boolean {
  const now = Date.now()
  const pattern = requestPatterns.get(fingerprint) || []
  
  pattern.push(now)
  
  // Keep only last 100 requests
  if (pattern.length > 100) {
    pattern.shift()
  }
  
  requestPatterns.set(fingerprint, pattern)
  
  // Check for rapid requests (more than 10 in 1 second)
  const recentRequests = pattern.filter(time => now - time < 1000)
  return recentRequests.length > 10
}

// Ultimate security middleware
export function ultimateSecurityMiddleware() {
  return async (req: NextRequest) => {
    // 1. Signature validation
    if (!validateSignature(req)) {
      return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
    }
    
    // 2. Request fingerprinting
    const fingerprint = generateFingerprint(req)
    
    // 3. Anomaly detection
    if (detectAnomaly(fingerprint)) {
      return NextResponse.json({ error: 'Anomalous behavior detected' }, { status: 429 })
    }
    
    // 4. Input sanitization
    if (req.method === 'POST' || req.method === 'PUT') {
      const body = await req.json()
      const sanitizedBody = sanitizeInput(body)
      
      // Replace request body with sanitized version
      const newReq = new NextRequest(req.url, {
        method: req.method,
        headers: req.headers,
        body: JSON.stringify(sanitizedBody)
      })
      
      return newReq
    }
    
    return NextResponse.next()
  }
}