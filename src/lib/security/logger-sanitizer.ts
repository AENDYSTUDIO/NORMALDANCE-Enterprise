export class LoggerSanitizer {
  static sanitizeLogInput(input: any): string {
    if (typeof input === 'string') {
      return input
        .replace(/[\r\n]/g, ' ')
        .replace(/[\x00-\x1f\x7f-\x9f]/g, '')
        .substring(0, 1000);
    }
    
    if (typeof input === 'object') {
      try {
        return JSON.stringify(input, null, 0).substring(0, 1000);
      } catch {
        return '[Object]';
      }
    }
    
    return String(input).substring(0, 1000);
  }

  static createSafeLogMessage(message: string, data?: any): string {
    const safeMessage = this.sanitizeLogInput(message);
    if (data) {
      const safeData = this.sanitizeLogInput(data);
      return `${safeMessage} | Data: ${safeData}`;
    }
    return safeMessage;
  }
}