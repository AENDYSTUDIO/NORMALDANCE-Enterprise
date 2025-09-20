// Golden Signals Implementation
import { Counter, Gauge, Histogram, register } from "prom-client";

// Latency
export const httpDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
});

// Traffic
export const httpRequests = new Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
});

// Errors
export const httpErrors = new Counter({
  name: "http_errors_total",
  help: "Total number of HTTP errors",
  labelNames: ["method", "route", "error_type"],
});

// Saturation
export const memoryUsage = new Gauge({
  name: "nodejs_memory_usage_bytes",
  help: "Memory usage in bytes",
  labelNames: ["type"],
});

// Business Metrics
export const activeUsers = new Gauge({
  name: "active_users_total",
  help: "Number of active users",
});

export const tracksUploaded = new Counter({
  name: "tracks_uploaded_total",
  help: "Total tracks uploaded",
});

// SLI/SLO Tracking
export const sloViolations = new Counter({
  name: "slo_violations_total",
  help: "SLO violations count",
  labelNames: ["service", "slo_type"],
});

// Middleware for automatic metrics collection
export function metricsMiddleware() {
  return (req: any, res: any, next: any) => {
    const start = Date.now();

    res.on("finish", () => {
      const duration = (Date.now() - start) / 1000;
      const route = req.route?.path || req.path;

      httpDuration.observe(
        { method: req.method, route, status_code: res.statusCode },
        duration
      );

      httpRequests.inc({
        method: req.method,
        route,
        status_code: res.statusCode,
      });

      if (res.statusCode >= 400) {
        httpErrors.inc({
          method: req.method,
          route,
          error_type: res.statusCode >= 500 ? "server" : "client",
        });
      }

      // SLO tracking
      if (duration > 0.5) {
        // 500ms SLO
        sloViolations.inc({ service: "api", slo_type: "latency" });
      }
    });

    next();
  };
}

register.registerMetric(httpDuration);
register.registerMetric(httpRequests);
register.registerMetric(httpErrors);
register.registerMetric(memoryUsage);
register.registerMetric(activeUsers);
register.registerMetric(tracksUploaded);
register.registerMetric(sloViolations);
