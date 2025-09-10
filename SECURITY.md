# 🔒 Security Guidelines

## Security Vulnerabilities Fixed

### XSS Prevention
- All user inputs are sanitized using `SecuritySanitizer`
- HTML content is purified with DOMPurify
- Input validation with length limits

### Path Traversal Prevention
- File paths validated with `PathValidator`
- Restricted to allowed directories
- Filename sanitization

### Log Injection Prevention
- Log inputs sanitized with `LoggerSanitizer`
- Newlines and control characters removed
- Input length limits enforced

## Security Best Practices

### Input Validation
```typescript
import { SecuritySanitizer } from '@/lib/security/sanitizer';

// Always validate user input
const safeTitle = SecuritySanitizer.validateInput(userInput, 255);
```

### File Operations
```typescript
import { PathValidator } from '@/lib/security/path-validator';

// Validate file paths
const safePath = PathValidator.validatePath(userPath, '/allowed/dir');
```

### Logging
```typescript
import { LoggerSanitizer } from '@/lib/security/logger-sanitizer';

// Sanitize log data
const safeMessage = LoggerSanitizer.createSafeLogMessage(message, data);
```

## Reporting Security Issues

Report security vulnerabilities to: security@normaldance.com