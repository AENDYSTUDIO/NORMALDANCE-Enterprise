# 🧪 Testing Guide

## Test Coverage Requirements

- **Minimum Coverage**: 80% for all metrics
- **Security Tests**: Required for all user input handling
- **API Tests**: Required for all endpoints
- **Component Tests**: Required for all React components

## Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run security tests only
npm test -- tests/security

# Run API tests only
npm test -- tests/api
```

## Test Structure

```
tests/
├── security/          # Security-focused tests
├── api/              # API endpoint tests
├── components/       # React component tests
├── integration/      # Integration tests
└── __mocks__/       # Mock files
```

## Writing Security Tests

```typescript
import { SecuritySanitizer } from '@/lib/security/sanitizer';

describe('Security', () => {
  it('should prevent XSS', () => {
    const malicious = '<script>alert("xss")</script>';
    const safe = SecuritySanitizer.sanitizeText(malicious);
    expect(safe).not.toContain('<script>');
  });
});
```

## Test Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Security modules | 100% |
| API routes | 90% |
| React components | 85% |
| Utilities | 80% |