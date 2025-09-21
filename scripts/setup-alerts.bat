@echo off
echo 🚨 Setting up NORMALDANCE Alerts
echo ===============================

echo.
echo Configuring alert channels...
echo.
echo 1. Email Alerts:
echo    - Admin: admin@normaldance.com
echo    - Team: team@normaldance.com
echo.
echo 2. Slack Integration:
echo    - Create webhook at: https://api.slack.com/apps
echo    - Add webhook URL to alertmanager.yml
echo.
echo 3. Discord Integration (optional):
echo    - Create webhook in Discord server
echo    - Configure in alertmanager.yml
echo.
echo 4. PagerDuty Integration (optional):
echo    - Get integration key from PagerDuty
echo    - Add to alertmanager.yml
echo.
echo ✅ Alert rules already configured in:
echo    - monitoring/prometheus/alert_rules.yml
echo    - monitoring/alertmanager/alertmanager.yml
echo.
echo Next steps:
echo 1. Update email settings in alertmanager.yml
echo 2. Add Slack webhook URL
echo 3. Restart monitoring stack
echo.
pause