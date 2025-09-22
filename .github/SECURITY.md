# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### 🔒 Private Disclosure

1. **DO NOT** create a public GitHub issue
2. Email security@normaldance.com with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact assessment
   - Your contact information

### 📋 What to Include

- **Vulnerability Type**: XSS, SQL Injection, etc.
- **Affected Components**: Specific files/functions
- **Attack Scenario**: How it could be exploited
- **Proof of Concept**: Code or screenshots
- **Suggested Fix**: If you have one

### ⏱️ Response Timeline

- **Initial Response**: Within 24 hours
- **Triage**: Within 72 hours
- **Fix Timeline**: 7-30 days depending on severity
- **Public Disclosure**: After fix is deployed

### 🏆 Recognition

We maintain a security hall of fame for responsible disclosure:
- Public recognition (with permission)
- Potential bounty rewards for critical findings
- Direct communication with our security team

## Security Measures

### 🛡️ Current Protections

- **Authentication**: Multi-factor authentication support
- **Authorization**: Role-based access control (RBAC)
- **Input Validation**: Comprehensive sanitization
- **Output Encoding**: XSS prevention
- **HTTPS**: Enforced SSL/TLS
- **Headers**: Security headers implementation
- **Rate Limiting**: API and authentication endpoints
- **Monitoring**: Real-time security monitoring
- **Auditing**: Comprehensive audit logging

### 🔐 Data Protection

- **Encryption at Rest**: AES-256 encryption
- **Encryption in Transit**: TLS 1.3
- **Key Management**: Secure key rotation
- **PII Handling**: GDPR/CCPA compliant
- **Data Retention**: Automated cleanup policies

### 🚨 Incident Response

1. **Detection**: Automated monitoring alerts
2. **Assessment**: Security team evaluation
3. **Containment**: Immediate threat mitigation
4. **Investigation**: Root cause analysis
5. **Recovery**: System restoration
6. **Lessons Learned**: Process improvement

## Security Best Practices

### For Developers

```typescript
// ✅ Good: Input validation
const validateInput = (input: string) => {
  return z.string().min(1).max(100).parse(input);
};

// ❌ Bad: Direct database query
const getUserById = (id: string) => {
  return db.query(`SELECT * FROM users WHERE id = ${id}`);
};

// ✅ Good: Parameterized query
const getUserById = (id: string) => {
  return db.user.findUnique({ where: { id } });
};
```

### For Operations

- Regular security updates
- Principle of least privilege
- Network segmentation
- Backup encryption
- Access logging
- Incident response drills

## Compliance

- **SOC 2 Type II**: Annual certification
- **GDPR**: EU data protection compliance
- **CCPA**: California privacy compliance
- **PCI DSS**: Payment card security (if applicable)

## Contact

- **Security Team**: security@normaldance.com
- **General Contact**: support@normaldance.com
- **Emergency**: security-emergency@normaldance.com

---

*Last updated: January 2025*