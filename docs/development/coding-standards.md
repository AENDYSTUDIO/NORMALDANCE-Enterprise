# 📋 NORMALDANCE Coding Standards

## 🎯 Code Quality Standards

### TypeScript Standards
- **Strict mode**: Always enabled
- **No any types**: Use proper typing
- **Interface over type**: Prefer interfaces
- **Explicit return types**: For all functions

### Code Style
```typescript
// ✅ Good
interface UserProfile {
  id: string
  email: string
  walletAddress?: string
}

async function getUserProfile(userId: string): Promise<UserProfile> {
  const user = await db.user.findUnique({ where: { id: userId } })
  if (!user) throw new Error('User not found')
  return user
}

// ❌ Bad
function getUser(id: any): any {
  return db.user.findUnique({ where: { id } })
}
```

### Security Standards
- **Input validation**: All inputs validated
- **SQL injection**: Use parameterized queries
- **XSS prevention**: Sanitize all outputs
- **Authentication**: JWT with short expiration

### Performance Standards
- **Bundle size**: <2MB total
- **First paint**: <1.5s
- **Time to interactive**: <3s
- **Memory usage**: <512MB per instance

### Testing Standards
- **Unit tests**: 95%+ coverage
- **Integration tests**: All API endpoints
- **E2E tests**: Critical user flows
- **Security tests**: All auth flows

## 📏 Metrics & Monitoring

### Code Quality Metrics
- **Cyclomatic complexity**: <10
- **Function length**: <50 lines
- **File length**: <500 lines
- **Dependency depth**: <5 levels

### Performance Metrics
- **Lighthouse score**: 95+
- **Core Web Vitals**: All green
- **API response time**: <200ms
- **Database queries**: <100ms

## 🔧 Tools & Configuration

### ESLint Configuration
```json
{
  "extends": [
    "@typescript-eslint/recommended",
    "next/core-web-vitals",
    "plugin:security/recommended"
  ],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/explicit-function-return-type": "error",
    "security/detect-object-injection": "error"
  }
}
```

### Prettier Configuration
```json
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```