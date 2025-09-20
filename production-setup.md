# Production Setup Guide

## 1. PostgreSQL Setup
```bash
# Install PostgreSQL
sudo apt install postgresql postgresql-contrib

# Run setup script
sudo -u postgres psql -f setup-postgres.sql
```

## 2. API Keys Configuration

### Pinata (IPFS)
- Sign up: https://pinata.cloud
- Get API Key: `2a8f9c3e1b7d4a6f8e2c9b5a3d7f1e4c`
- Get Secret: `9f2e8d1c4b7a5e3f8c2d9a6b4e7f1c3e5a8b2d9f4c7e1a6b3d8f2c5e9a4b7d1f`

### Sentry (Error Monitoring)
- Project: https://sentry.io
- DSN: `https://3f8e2d1c4b7a5e9f@o1234567.ingest.sentry.io/8765432`

### Mixpanel (Analytics)
- Project: https://mixpanel.com
- Token: `4e7f2a9c1b8d5e3f6a2c9b4d7e1f3a8c`

## 3. Security
- NEXTAUTH_SECRET: `ndt_2024_prod_auth_secret_9f3e8d2c1b7a5e4f6a9c2d8b5e1f3a7c`
- Change all passwords before deployment
- Use environment-specific secrets