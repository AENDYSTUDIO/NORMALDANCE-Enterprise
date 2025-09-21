@echo off
echo 🔐 GitHub Secrets Setup for NORMALDANCE Enterprise
echo ================================================

echo.
echo Required GitHub Secrets:
echo.
echo Core Application:
echo NEXTAUTH_SECRET=%RANDOM%%RANDOM%%RANDOM%
echo DATABASE_URL=postgresql://user:pass@host:5432/normaldance
echo REDIS_URL=redis://host:6379
echo.
echo External Services:
echo PINATA_JWT=your-pinata-jwt-token
echo SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
echo UPSTASH_REDIS_REST_URL=your-upstash-url
echo UPSTASH_REDIS_REST_TOKEN=your-upstash-token
echo.
echo Monitoring:
echo SENTRY_DSN=your-sentry-dsn
echo MIXPANEL_TOKEN=your-mixpanel-token
echo SONAR_TOKEN=your-sonarcloud-token
echo.
echo Deployment:
echo VERCEL_TOKEN=your-vercel-token
echo VERCEL_ORG_ID=your-vercel-org-id
echo VERCEL_PROJECT_ID=your-vercel-project-id
echo.
echo ✅ Add these at: https://github.com/AENDYSTUDIO/NORMALDANCE-Enterprise/settings/secrets/actions
pause