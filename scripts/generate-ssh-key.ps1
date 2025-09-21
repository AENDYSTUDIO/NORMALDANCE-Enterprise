# NORMALDANCE SSH Key Generator
# Простой скрипт для генерации SSH ключа

Write-Host "🔑 NORMALDANCE SSH Key Generator" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Проверка Git
try {
    $null = git --version
    Write-Host "✅ Git установлен" -ForegroundColor Green
} catch {
    Write-Host "❌ Git не установлен. Установите Git перед продолжением." -ForegroundColor Red
    exit 1
}

# Генерация SSH ключа
$keyName = "normaldance-github"
$keyPath = Join-Path $env:USERPROFILE ".ssh\$keyName"
$publicKeyPath = "$keyPath.pub"

Write-Host "🔑 Генерация SSH ключа..." -ForegroundColor Yellow

if (Test-Path $keyPath) {
    Write-Host "⚠️  SSH ключ уже существует: $keyPath" -ForegroundColor Yellow
    $overwrite = Read-Host "Перезаписать? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Пропуск генерации SSH ключа" -ForegroundColor Yellow
        exit 0
    }
}

# Создание директории .ssh если не существует
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Host "📁 Создана директория: $sshDir" -ForegroundColor Green
}

# Генерация ключа
$comment = "normaldance-github-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "🔧 Генерация ключа с комментарием: $comment" -ForegroundColor Yellow

ssh-keygen -t ed25519 -f $keyPath -C $comment -N '""'

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SSH ключ успешно сгенерирован" -ForegroundColor Green
    
    # Чтение публичного ключа
    if (Test-Path $publicKeyPath) {
        $publicKey = Get-Content $publicKeyPath -Raw
        Write-Host ""
        Write-Host "📋 Публичный ключ:" -ForegroundColor Cyan
        Write-Host "==================" -ForegroundColor Cyan
        Write-Host $publicKey.Trim()
        Write-Host "==================" -ForegroundColor Cyan
        Write-Host ""
        
        # Инструкции по добавлению в GitHub
        Write-Host "🔧 Инструкции по добавлению ключа в GitHub:" -ForegroundColor Yellow
        Write-Host "1. Перейдите в GitHub Settings > SSH and GPG keys" -ForegroundColor White
        Write-Host "2. Нажмите 'New SSH key'" -ForegroundColor White
        Write-Host "3. Введите название: NORMALDANCE-Access" -ForegroundColor White
        Write-Host "4. Скопируйте публичный ключ выше" -ForegroundColor White
        Write-Host "5. Нажмите 'Add SSH key'" -ForegroundColor White
        Write-Host ""
        
        # Проверка GitHub CLI
        try {
            $null = gh --version
            Write-Host "🔐 GitHub CLI обнаружен. Добавить ключ автоматически? (y/N)" -ForegroundColor Yellow
            $autoAdd = Read-Host
            if ($autoAdd -eq "y" -or $autoAdd -eq "Y") {
                Write-Host "🔐 Аутентификация в GitHub CLI..." -ForegroundColor Yellow
                gh auth login
                
                if ($LASTEXITCODE -eq 0) {
                    $publicKey | gh ssh-key add - -t "NORMALDANCE-Access"
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✅ Ключ успешно добавлен в GitHub" -ForegroundColor Green
                    } else {
                        Write-Host "❌ Ошибка добавления ключа в GitHub" -ForegroundColor Red
                    }
                }
            }
        } catch {
            Write-Host "ℹ️  GitHub CLI не установлен. Добавьте ключ вручную по инструкциям выше." -ForegroundColor Cyan
        }
        
        # Настройка SSH конфигурации
        Write-Host ""
        Write-Host "⚙️  Настройка SSH конфигурации..." -ForegroundColor Yellow
        
        $configPath = Join-Path $sshDir "config"
        $configContent = @"

# NORMALDANCE GitHub Access Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile $keyPath
    IdentitiesOnly yes
    AddKeysToAgent yes

Host github-normaldance
    HostName github.com
    User git
    IdentityFile $keyPath
    IdentitiesOnly yes
    AddKeysToAgent yes
"@

        if (Test-Path $configPath) {
            $existingConfig = Get-Content $configPath -Raw
            if ($existingConfig -notmatch "NORMALDANCE") {
                Add-Content -Path $configPath -Value $configContent
                Write-Host "✅ SSH конфигурация обновлена" -ForegroundColor Green
            } else {
                Write-Host "✅ SSH конфигурация уже настроена" -ForegroundColor Green
            }
        } else {
            Set-Content -Path $configPath -Value $configContent
            Write-Host "✅ SSH конфигурация создана" -ForegroundColor Green
        }
        
        # Проверка подключения
        Write-Host ""
        Write-Host "🔍 Проверка подключения к GitHub..." -ForegroundColor Yellow
        
        try {
            $sshTest = ssh -T git@github.com 2>&1
            if ($sshTest -match "successfully authenticated") {
                Write-Host "✅ Подключение к GitHub работает" -ForegroundColor Green
            } else {
                Write-Host "⚠️  SSH подключение к GitHub не настроено" -ForegroundColor Yellow
                Write-Host "Убедитесь, что ключ добавлен в GitHub" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠️  SSH подключение к GitHub не настроено" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "❌ Ошибка чтения публичного ключа" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Ошибка генерации SSH ключа" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Генерация SSH ключа завершена!" -ForegroundColor Green
Write-Host ""
Write-Host "📚 Дополнительная информация:" -ForegroundColor Cyan
Write-Host "• Документация: docs/SECURITY_WORKFLOW.md" -ForegroundColor White
Write-Host "• Приватный ключ: $keyPath" -ForegroundColor White
Write-Host "• Публичный ключ: $publicKeyPath" -ForegroundColor White
Write-Host ""
