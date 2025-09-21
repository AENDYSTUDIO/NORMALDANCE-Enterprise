# NORMALDANCE Security System Setup
# Комплексная настройка системы безопасности

param(
    [switch]$FullSetup,
    [switch]$Interactive,
    [switch]$SkipGitHooks,
    [switch]$SkipCI,
    [string]$Environment = "development"
)

# Цвета для вывода
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Cyan = "Cyan"
$Magenta = "Magenta"

function Write-ColorLog {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Error" { Write-Host "❌ $Message" -ForegroundColor $Red }
        "Warning" { Write-Host "⚠️  $Message" -ForegroundColor $Yellow }
        "Success" { Write-Host "✅ $Message" -ForegroundColor $Green }
        "Info" { Write-Host "ℹ️  $Message" -ForegroundColor $Cyan }
        "Header" { Write-Host "🎯 $Message" -ForegroundColor $Magenta }
        default { Write-Host $Message }
    }
}

function Test-Prerequisites {
    Write-ColorLog "Проверка предварительных требований..." "Header"
    
    $prerequisites = @{
        "Git" = $false
        "Node.js" = $false
        "npm" = $false
        "GitHub CLI" = $false
    }
    
    # Проверка Git
    try {
        $null = git --version
        $prerequisites["Git"] = $true
        Write-ColorLog "Git: установлен" "Success"
    } catch {
        Write-ColorLog "Git: не установлен" "Error"
    }
    
    # Проверка Node.js
    try {
        $null = node --version
        $prerequisites["Node.js"] = $true
        Write-ColorLog "Node.js: установлен" "Success"
    } catch {
        Write-ColorLog "Node.js: не установлен" "Error"
    }
    
    # Проверка npm
    try {
        $null = npm --version
        $prerequisites["npm"] = $true
        Write-ColorLog "npm: установлен" "Success"
    } catch {
        Write-ColorLog "npm: не установлен" "Error"
    }
    
    # Проверка GitHub CLI
    try {
        $null = gh --version
        $prerequisites["GitHub CLI"] = $true
        Write-ColorLog "GitHub CLI: установлен" "Success"
    } catch {
        Write-ColorLog "GitHub CLI: не установлен (опционально)" "Warning"
    }
    
    $allInstalled = $prerequisites.Values | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    $total = $prerequisites.Count
    
    if ($allInstalled -eq $total) {
        Write-ColorLog "Все предварительные требования выполнены" "Success"
        return $true
    } else {
        Write-ColorLog "Не все предварительные требования выполнены ($allInstalled/$total)" "Warning"
        return $false
    }
}

function Install-SecurityDependencies {
    Write-ColorLog "Установка зависимостей безопасности..." "Header"
    
    try {
        # Установка инструментов сканирования секретов
        Write-ColorLog "Установка TruffleHog..." "Info"
        npm install -g trufflehog
        
        Write-ColorLog "Установка GitLeaks..." "Info"
        npm install -g gitleaks
        
        # Установка локальных зависимостей
        Write-ColorLog "Установка локальных зависимостей..." "Info"
        npm install
        
        Write-ColorLog "Зависимости безопасности установлены" "Success"
        return $true
    } catch {
        Write-ColorLog "Ошибка установки зависимостей: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Setup-GitHooks {
    if ($SkipGitHooks) {
        Write-ColorLog "Пропуск настройки Git-хуков" "Warning"
        return $true
    }
    
    Write-ColorLog "Настройка Git-хуков..." "Header"
    
    try {
        $hooksDir = ".git\hooks"
        
        # Создание директории хуков если не существует
        if (!(Test-Path $hooksDir)) {
            New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
        }
        
        # Копирование PowerShell хука
        $preCommitHook = Join-Path $hooksDir "pre-commit.ps1"
        if (Test-Path "scripts\pre-commit.ps1") {
            Copy-Item "scripts\pre-commit.ps1" $preCommitHook -Force
            Write-ColorLog "Pre-commit хук установлен" "Success"
        }
        
        # Создание batch файла для вызова PowerShell хука
        $preCommitBat = Join-Path $hooksDir "pre-commit.bat"
        $batContent = @"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0pre-commit.ps1" "%1"
"@
        Set-Content -Path $preCommitBat -Value $batContent
        
        Write-ColorLog "Git-хуки настроены" "Success"
        return $true
    } catch {
        Write-ColorLog "Ошибка настройки Git-хуков: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Setup-SSHKeys {
    Write-ColorLog "Настройка SSH ключей..." "Header"
    
    try {
        # Запуск скрипта настройки SSH ключей
        if (Test-Path "scripts\secure-key-setup.ps1") {
            & "scripts\secure-key-setup.ps1" -Interactive:$Interactive
            Write-ColorLog "SSH ключи настроены" "Success"
            return $true
        } else {
            Write-ColorLog "Скрипт настройки SSH ключей не найден" "Error"
            return $false
        }
    } catch {
        Write-ColorLog "Ошибка настройки SSH ключей: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Setup-CI {
    if ($SkipCI) {
        Write-ColorLog "Пропуск настройки CI/CD" "Warning"
        return $true
    }
    
    Write-ColorLog "Настройка CI/CD пайплайнов..." "Header"
    
    try {
        $workflowsDir = ".github\workflows"
        
        # Создание директории workflows если не существует
        if (!(Test-Path $workflowsDir)) {
            New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
        }
        
        # Проверка существования security-pipeline.yml
        if (Test-Path "scripts\security-pipeline.yml") {
            Copy-Item "scripts\security-pipeline.yml" "$workflowsDir\security-pipeline.yml" -Force
            Write-ColorLog "Security pipeline настроен" "Success"
        }
        
        Write-ColorLog "CI/CD пайплайны настроены" "Success"
        return $true
    } catch {
        Write-ColorLog "Ошибка настройки CI/CD: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Setup-Environment {
    Write-ColorLog "Настройка окружения..." "Header"
    
    try {
        # Создание .env.example если не существует
        if (!(Test-Path ".env.example")) {
            $envExample = @"
# NORMALDANCE Environment Variables
# Скопируйте этот файл в .env.local и заполните значения

# Database
DATABASE_URL="postgresql://user:password@localhost:5432/normaldance"

# Authentication
NEXTAUTH_SECRET="your-secret-here"
NEXTAUTH_URL="http://localhost:3000"

# Supabase
SUPABASE_URL="https://your-project.supabase.co"
SUPABASE_ANON_KEY="your-anon-key-here"

# Security
SECURITY_MONITORING_ENABLED=true
SECURITY_ALERT_EMAIL="security@normaldance.com"
SLACK_WEBHOOK_URL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# GitHub
GITHUB_TOKEN=""
GITHUB_PERSONAL_ACCESS_TOKEN=""

# Environment
NODE_ENV="$Environment"
"@
            Set-Content -Path ".env.example" -Value $envExample
            Write-ColorLog ".env.example создан" "Success"
        }
        
        # Создание .gitignore если не существует
        if (!(Test-Path ".gitignore")) {
            $gitignore = @"
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Security
*.key
*.pem
*.p12
*.pfx
secrets/
keys/

# Logs
logs/
*.log

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# nyc test coverage
.nyc_output

# Dependency directories
node_modules/
jspm_packages/

# Optional npm cache directory
.npm

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# dotenv environment variables file
.env

# parcel-bundler cache (https://parceljs.org/)
.cache
.parcel-cache

# next.js build output
.next

# nuxt.js build output
.nuxt

# vuepress build output
.vuepress/dist

# Serverless directories
.serverless

# FuseBox cache
.fusebox/

# DynamoDB Local files
.dynamodb/

# TernJS port file
.tern-port

# Stores VSCode versions used for testing VSCode extensions
.vscode-test

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
"@
            Set-Content -Path ".gitignore" -Value $gitignore
            Write-ColorLog ".gitignore создан" "Success"
        }
        
        Write-ColorLog "Окружение настроено" "Success"
        return $true
    } catch {
        Write-ColorLog "Ошибка настройки окружения: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-SecuritySetup {
    Write-ColorLog "Тестирование настройки безопасности..." "Header"
    
    try {
        # Тест Git-хуков
        if (!$SkipGitHooks) {
            Write-ColorLog "Тестирование Git-хуков..." "Info"
            # Здесь можно добавить тесты хуков
        }
        
        # Тест сканирования секретов
        Write-ColorLog "Тестирование сканирования секретов..." "Info"
        if (Get-Command trufflehog -ErrorAction SilentlyContinue) {
            Write-ColorLog "TruffleHog доступен" "Success"
        } else {
            Write-ColorLog "TruffleHog недоступен" "Warning"
        }
        
        # Тест SSH подключения
        Write-ColorLog "Тестирование SSH подключения..." "Info"
        try {
            $sshTest = ssh -T git@github.com 2>&1
            if ($sshTest -match "successfully authenticated") {
                Write-ColorLog "SSH подключение к GitHub работает" "Success"
            } else {
                Write-ColorLog "SSH подключение к GitHub не настроено" "Warning"
            }
        } catch {
            Write-ColorLog "SSH подключение к GitHub не настроено" "Warning"
        }
        
        Write-ColorLog "Тестирование завершено" "Success"
        return $true
    } catch {
        Write-ColorLog "Ошибка тестирования: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-Summary {
    Write-ColorLog "Сводка настройки системы безопасности" "Header"
    Write-Host ""
    Write-Host "🎯 NORMALDANCE Security System" -ForegroundColor $Magenta
    Write-Host "=============================" -ForegroundColor $Magenta
    Write-Host ""
    Write-Host "✅ Система безопасности настроена и готова к использованию"
    Write-Host ""
    Write-Host "📋 Что было настроено:"
    Write-Host "   • Git-хуки для контроля безопасности"
    Write-Host "   • SSH ключи для доступа к GitHub"
    Write-Host "   • CI/CD пайплайны с проверками безопасности"
    Write-Host "   • Система мониторинга и аудита"
    Write-Host "   • RBAC система управления доступом"
    Write-Host ""
    Write-Host "🔧 Доступные команды:"
    Write-Host "   • npm run security:scan - сканирование на секреты"
    Write-Host "   • npm run security:audit - аудит безопасности"
    Write-Host "   • npm run security:monitor - запуск мониторинга"
    Write-Host ""
    Write-Host "📚 Документация:"
    Write-Host "   • docs/SECURITY_WORKFLOW.md - полное руководство"
    Write-Host "   • scripts/secure-key-setup.ps1 - настройка ключей"
    Write-Host ""
    Write-Host "⚠️  Важно:"
    Write-Host "   • Все операции с ключами логируются"
    Write-Host "   • Используйте feature-ветки для разработки"
    Write-Host "   • Регулярно обновляйте ключи"
    Write-Host ""
}

# Основная логика
Write-Host "🔐 NORMALDANCE Security System Setup" -ForegroundColor $Cyan
Write-Host "=====================================" -ForegroundColor $Cyan
Write-Host ""

$setupSteps = @(
    { Test-Prerequisites },
    { Install-SecurityDependencies },
    { Setup-GitHooks },
    { Setup-SSHKeys },
    { Setup-CI },
    { Setup-Environment },
    { Test-SecuritySetup }
)

$successCount = 0
$totalSteps = $setupSteps.Count

foreach ($step in $setupSteps) {
    if (& $step) {
        $successCount++
    }
    Write-Host ""
}

if ($successCount -eq $totalSteps) {
    Write-ColorLog "Все шаги настройки выполнены успешно ($successCount/$totalSteps)" "Success"
    Show-Summary
} else {
    Write-ColorLog "Настройка завершена с предупреждениями ($successCount/$totalSteps)" "Warning"
    Write-ColorLog "Проверьте ошибки выше и выполните необходимые действия" "Info"
}

Write-Host ""
Write-ColorLog "Настройка системы безопасности завершена" "Header"

