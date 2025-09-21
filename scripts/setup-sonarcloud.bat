@echo off
echo 🔍 SonarCloud Setup for NORMALDANCE Enterprise
echo ============================================

echo.
echo Step 1: Go to https://sonarcloud.io
echo Step 2: Sign in with GitHub
echo Step 3: Import repository: AENDYSTUDIO/NORMALDANCE-Enterprise
echo Step 4: Get SONAR_TOKEN from project settings
echo Step 5: Add SONAR_TOKEN to GitHub Secrets
echo.
echo SonarCloud Project Key: AENDYSTUDIO_NORMALDANCE-Enterprise
echo Organization: aendystudio
echo.
echo ✅ Configuration file already created: sonar-project.properties
echo ✅ GitHub Action already configured: .github/workflows/sonarcloud.yml
echo.
echo Next: Add SONAR_TOKEN to GitHub Secrets and push to trigger analysis
pause