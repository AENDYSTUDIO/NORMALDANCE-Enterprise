@echo off
echo 📊 Starting NORMALDANCE Monitoring Stack
echo =======================================

echo Checking Docker...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker not found. Please install Docker Desktop
    pause
    exit /b 1
)

echo ✅ Docker found
echo.
echo Starting monitoring services...
docker-compose -f monitoring\docker-compose.monitoring.yml up -d

echo.
echo Waiting for services to start...
timeout /t 30 /nobreak >nul

echo.
echo 🎯 Monitoring Stack Status:
docker-compose -f monitoring\docker-compose.monitoring.yml ps

echo.
echo 🌐 Access URLs:
echo Prometheus: http://localhost:9090
echo Grafana: http://localhost:3001 (admin/admin123)
echo AlertManager: http://localhost:9093
echo Loki: http://localhost:3100
echo.
echo ✅ Monitoring stack started successfully!
pause