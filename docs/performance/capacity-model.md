# 📊 NORMALDANCE Capacity Model

## Little's Law Application

**Formula**: L = λ × W
- **L**: Number of requests in system
- **λ**: Arrival rate (RPS)
- **W**: Average response time

## Capacity Planning Matrix

| Target RPS | P99 Latency | Required Pods | Memory per Pod | CPU per Pod |
|------------|-------------|---------------|----------------|-------------|
| 1,000      | <200ms      | 2             | 512Mi          | 250m        |
| 5,000      | <200ms      | 10            | 512Mi          | 500m        |
| 10,000     | <200ms      | 20            | 1Gi            | 1000m       |
| 50,000     | <200ms      | 100           | 1Gi            | 1000m       |
| 100,000    | <200ms      | 200           | 2Gi            | 2000m       |
| 500,000    | <200ms      | 1000          | 2Gi            | 2000m       |
| 1,000,000  | <200ms      | 2000          | 4Gi            | 4000m       |

## Database Scaling Model

| Concurrent Users | DB Connections | Read Replicas | Write Capacity |
|------------------|----------------|---------------|----------------|
| 10,000          | 200            | 2             | 5,000 TPS      |
| 50,000          | 500            | 5             | 25,000 TPS     |
| 100,000         | 1,000          | 10            | 50,000 TPS     |
| 500,000         | 2,000          | 20            | 250,000 TPS    |
| 1,000,000       | 4,000          | 40            | 500,000 TPS    |

## Performance Benchmarks

### Load Testing Results
- **1,000 RPS**: 150ms p95, 0% errors
- **10,000 RPS**: 180ms p95, 0.01% errors
- **50,000 RPS**: 200ms p95, 0.05% errors
- **100,000 RPS**: 250ms p95, 0.1% errors

### Bottleneck Analysis
1. **Database**: First bottleneck at 25,000 RPS
2. **Memory**: Becomes critical at 100,000 RPS
3. **Network**: Saturates at 500,000 RPS
4. **CPU**: Limits at 1,000,000 RPS

**Updated**: 2025-01-27  
**Next Review**: 2025-02-27