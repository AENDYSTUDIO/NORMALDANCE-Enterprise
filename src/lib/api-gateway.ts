import { NextRequest, NextResponse } from 'next/server';
import rateLimit from 'express-rate-limit';

export class APIGateway {
  private static limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP'
  });

  static async authenticate(request: NextRequest): Promise<boolean> {
    const token = request.headers.get('authorization')?.replace('Bearer ', '');
    if (!token) return false;
    
    try {
      // JWT validation logic here
      return true;
    } catch {
      return false;
    }
  }

  static async authorize(request: NextRequest, requiredRole: string): Promise<boolean> {
    // Role-based access control
    return true;
  }

  static createErrorResponse(message: string, status: number = 400) {
    return NextResponse.json({ error: message }, { status });
  }
}