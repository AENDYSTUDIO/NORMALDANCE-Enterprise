import { NextRequest, NextResponse } from 'next/server'
import { adaptiveLimit, geoLimit, behaviorLimit } from './middleware/advanced-rate-limiter'
import { ultimateSecurityMiddleware } from './middleware/ultimate-security'

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  
  // Apply security layers
  const securityResult = await ultimateSecurityMiddleware()(request)
  if (securityResult instanceof NextResponse) {
    return securityResult
  }
  
  // Apply rate limiting based on path
  if (pathname.startsWith('/api/')) {
    // Adaptive rate limiting
    const adaptiveResult = await adaptiveLimit(request as any, NextResponse as any, () => {})
    if (adaptiveResult) return adaptiveResult
    
    // Geographic filtering
    const geoResult = await geoLimit(request as any, NextResponse as any, () => {})
    if (geoResult) return geoResult
    
    // Behavioral analysis
    const behaviorResult = await behaviorLimit(request as any, NextResponse as any, () => {})
    if (behaviorResult) return behaviorResult
  }
  
  // Security headers
  const response = NextResponse.next()
  
  response.headers.set('X-Frame-Options', 'DENY')
  response.headers.set('X-Content-Type-Options', 'nosniff')
  response.headers.set('X-XSS-Protection', '1; mode=block')
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  response.headers.set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()')
  response.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload')
  
  // CSP
  response.headers.set('Content-Security-Policy', 
    "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https:; font-src 'self' https:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none';"
  )
  
  return response
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}