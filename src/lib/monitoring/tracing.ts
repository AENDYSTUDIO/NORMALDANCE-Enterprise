export class DistributedTracing {
  static trace<T>(name: string, fn: () => T, attributes?: Record<string, string>): T {
    const startTime = Date.now();
    console.log(`[TRACE] Starting: ${name}`, attributes);
    
    try {
      const result = fn();
      const duration = Date.now() - startTime;
      console.log(`[TRACE] Completed: ${name} (${duration}ms)`);
      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      console.error(`[TRACE] Failed: ${name} (${duration}ms)`, error);
      throw error;
    }
  }
}