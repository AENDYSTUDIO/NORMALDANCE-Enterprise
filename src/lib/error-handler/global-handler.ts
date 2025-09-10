import { LoggerSanitizer } from '@/lib/security/logger-sanitizer';

export class GlobalErrorHandler {
  static handle(error: Error, context: string, userId?: string) {
    const sanitizedMessage = LoggerSanitizer.createSafeLogMessage(error.message, {
      context,
      userId,
      stack: error.stack?.substring(0, 500)
    });
    
    console.error(sanitizedMessage);
  }

  static createApiError(message: string, status: number = 500) {
    return {
      error: LoggerSanitizer.sanitizeLogInput(message),
      status,
      timestamp: new Date().toISOString()
    };
  }
}