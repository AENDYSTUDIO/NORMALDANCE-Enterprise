# NORMALDANCE Quick Security Setup
# Быстрая настройка системы безопасности

param(
    [switch]$Interactive
)

Write-Host "🔐 NORMALDANCE Quick Security Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Проверка предварительных требований
Write-Host "🔍 Проверка предварительных требований..." -ForegroundColor Yellow

$gitInstalled = $false
$nodeInstalled = $false

try {
    $null = git --version
    $gitInstalled = $true
    Write-Host "✅ Git: установлен" -ForegroundColor Green
} catch {
    Write-Host "❌ Git: не установлен" -ForegroundColor Red
}

try {
    $null = node --version
    $nodeInstalled = $true
    Write-Host "✅ Node.js: установлен" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js: не установлен" -ForegroundColor Red
}

if (!$gitInstalled -or !$nodeInstalled) {
    Write-Host ""
    Write-Host "❌ Не все предварительные требования выполнены" -ForegroundColor Red
    Write-Host "Установите Git и Node.js перед продолжением" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✅ Все предварительные требования выполнены" -ForegroundColor Green
Write-Host ""

# Настройка SSH ключей
Write-Host "🔑 Настройка SSH ключей..." -ForegroundColor Yellow

$sshKeyName = "normaldance-github"
$sshKeyPath = Join-Path $env:USERPROFILE ".ssh\$sshKeyName"

if (Test-Path $sshKeyPath) {
    Write-Host "⚠️  SSH ключ уже существует: $sshKeyPath" -ForegroundColor Yellow
    $overwrite = Read-Host "Перезаписать? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Пропуск генерации SSH ключа" -ForegroundColor Yellow
    } else {
        # Генерация нового ключа
        $comment = "normaldance-github-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        ssh-keygen -t ed25519 -f $sshKeyPath -C $comment -N '""'
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ SSH ключ успешно сгенерирован" -ForegroundColor Green
            
            # Чтение публичного ключа
            $publicKeyPath = "$sshKeyPath.pub"
            if (Test-Path $publicKeyPath) {
                $publicKey = Get-Content $publicKeyPath -Raw
                Write-Host ""
                Write-Host "📋 Публичный ключ:" -ForegroundColor Cyan
                Write-Host $publicKey.Trim()
                Write-Host ""
                
                # Предложение добавить ключ в GitHub
                $addToGitHub = Read-Host "Добавить ключ в GitHub? (y/N)"
                if ($addToGitHub -eq "y" -or $addToGitHub -eq "Y") {
                    try {
                        $null = gh --version
                        Write-Host "🔐 Требуется аутентификация в GitHub CLI..." -ForegroundColor Yellow
                        gh auth login
                        
                        if ($LASTEXITCODE -eq 0) {
                            $publicKey | gh ssh-key add - -t "NORMALDANCE-Access"
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "✅ Ключ успешно добавлен в GitHub" -ForegroundColor Green
                            } else {
                                Write-Host "❌ Ошибка добавления ключа в GitHub" -ForegroundColor Red
                            }
                        }
                    } catch {
                        Write-Host "⚠️  GitHub CLI не установлен. Добавьте ключ вручную:" -ForegroundColor Yellow
                        Write-Host "1. Перейдите в GitHub Settings > SSH and GPG keys" -ForegroundColor Yellow
                        Write-Host "2. Нажмите 'New SSH key'" -ForegroundColor Yellow
                        Write-Host "3. Скопируйте публичный ключ выше" -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host "❌ Ошибка генерации SSH ключа" -ForegroundColor Red
        }
    }
} else {
    # Генерация нового ключа
    $comment = "normaldance-github-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    ssh-keygen -t ed25519 -f $sshKeyPath -C $comment -N '""'
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SSH ключ успешно сгенерирован" -ForegroundColor Green
        
        # Чтение публичного ключа
        $publicKeyPath = "$sshKeyPath.pub"
        if (Test-Path $publicKeyPath) {
            $publicKey = Get-Content $publicKeyPath -Raw
            Write-Host ""
            Write-Host "📋 Публичный ключ:" -ForegroundColor Cyan
            Write-Host $publicKey.Trim()
            Write-Host ""
            
            # Предложение добавить ключ в GitHub
            $addToGitHub = Read-Host "Добавить ключ в GitHub? (y/N)"
            if ($addToGitHub -eq "y" -or $addToGitHub -eq "Y") {
                try {
                    $null = gh --version
                    Write-Host "🔐 Требуется аутентификация в GitHub CLI..." -ForegroundColor Yellow
                    gh auth login
                    
                    if ($LASTEXITCODE -eq 0) {
                        $publicKey | gh ssh-key add - -t "NORMALDANCE-Access"
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "✅ Ключ успешно добавлен в GitHub" -ForegroundColor Green
                        } else {
                            Write-Host "❌ Ошибка добавления ключа в GitHub" -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Host "⚠️  GitHub CLI не установлен. Добавьте ключ вручную:" -ForegroundColor Yellow
                    Write-Host "1. Перейдите в GitHub Settings > SSH and GPG keys" -ForegroundColor Yellow
                    Write-Host "2. Нажмите 'New SSH key'" -ForegroundColor Yellow
                    Write-Host "3. Скопируйте публичный ключ выше" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "❌ Ошибка генерации SSH ключа" -ForegroundColor Red
    }
}

Write-Host ""

# Настройка SSH конфигурации
Write-Host "⚙️  Настройка SSH конфигурации..." -ForegroundColor Yellow

$sshDir = Join-Path $env:USERPROFILE ".ssh"
$configPath = Join-Path $sshDir "config"

$configContent = @"
# NORMALDANCE GitHub Access Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile $sshKeyPath
    IdentitiesOnly yes
    AddKeysToAgent yes

Host github-normaldance
    HostName github.com
    User git
    IdentityFile $sshKeyPath
    IdentitiesOnly yes
    AddKeysToAgent yes
"@

try {
    if (!(Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    
    if (Test-Path $configPath) {
        $existingConfig = Get-Content $configPath -Raw
        if ($existingConfig -notmatch "NORMALDANCE GitHub Access Configuration") {
            Add-Content -Path $configPath -Value "`n$configContent"
        }
    } else {
        Set-Content -Path $configPath -Value $configContent
    }
    
    Write-Host "✅ SSH конфигурация обновлена" -ForegroundColor Green
} catch {
    Write-Host "❌ Ошибка настройки SSH: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Проверка подключения к GitHub
Write-Host "🔍 Проверка подключения к GitHub..." -ForegroundColor Yellow

try {
    $sshTest = ssh -T git@github.com 2>&1
    if ($sshTest -match "successfully authenticated") {
        Write-Host "✅ Подключение к GitHub работает" -ForegroundColor Green
    } else {
        Write-Host "⚠️  SSH подключение к GitHub не настроено" -ForegroundColor Yellow
        Write-Host "Проверьте настройки SSH ключей" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  SSH подключение к GitHub не настроено" -ForegroundColor Yellow
}

Write-Host ""

# Создание .env.example
Write-Host "📝 Создание .env.example..." -ForegroundColor Yellow

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

# GitHub
GITHUB_TOKEN=""
GITHUB_PERSONAL_ACCESS_TOKEN=""

# Environment
NODE_ENV="development"
"@
    Set-Content -Path ".env.example" -Value $envExample
    Write-Host "✅ .env.example создан" -ForegroundColor Green
} else {
    Write-Host "✅ .env.example уже существует" -ForegroundColor Green
}

Write-Host ""

# Сводка
Write-Host "🎯 Сводка настройки" -ForegroundColor Magenta
Write-Host "===================" -ForegroundColor Magenta
Write-Host ""
Write-Host "✅ Система безопасности настроена"
Write-Host ""
Write-Host "📋 Что было настроено:"
Write-Host "   • SSH ключи для доступа к GitHub"
Write-Host "   • SSH конфигурация"
Write-Host "   • Файл .env.example"
Write-Host ""
Write-Host "🔧 Следующие шаги:"
Write-Host "   • Скопируйте .env.example в .env.local"
Write-Host "   • Заполните переменные окружения"
Write-Host "   • Запустите: npm run dev"
Write-Host ""
Write-Host "📚 Документация:"
Write-Host "   • docs/SECURITY_WORKFLOW.md - полное руководство"
Write-Host ""
Write-Host "⚠️  Важно:"
Write-Host "   • Никогда не коммитьте .env файлы"
Write-Host "   • Используйте feature-ветки для разработки"
Write-Host "   • Регулярно обновляйте ключи"
Write-Host ""

Write-Host "🎉 Настройка завершена!" -ForegroundColor Green

