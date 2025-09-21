# NORMALDANCE Git Configuration Cleaner
# Полная очистка старых Git и GitHub конфигураций

param(
    [switch]$Force
)

Write-Host "NORMALDANCE Git Configuration Cleaner" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

function Show-CurrentConfig {
    Write-Host "Текущая конфигурация Git:" -ForegroundColor Yellow
    Write-Host ""
    
    # Глобальная конфигурация
    Write-Host "Глобальная конфигурация:" -ForegroundColor Green
    try {
        git config --global --list
    } catch {
        Write-Host "Ошибка чтения глобальной конфигурации" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Локальная конфигурация
    Write-Host "Локальная конфигурация:" -ForegroundColor Green
    try {
        git config --local --list
    } catch {
        Write-Host "Ошибка чтения локальной конфигурации" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Show-SSHKeys {
    Write-Host "SSH ключи:" -ForegroundColor Yellow
    Write-Host ""
    
    $sshDir = "$env:USERPROFILE\.ssh"
    if (Test-Path $sshDir) {
        Write-Host "SSH директория: $sshDir" -ForegroundColor Green
        Get-ChildItem -Path $sshDir -Force | ForEach-Object {
            $type = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
            Write-Host "   $type $($_.Name)" -ForegroundColor White
        }
    } else {
        Write-Host "SSH директория не найдена" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Show-GitHubDesktopConfig {
    Write-Host "GitHub Desktop конфигурация:" -ForegroundColor Yellow
    Write-Host ""
    
    $githubDesktopDir = "$env:APPDATA\GitHubDesktop"
    if (Test-Path $githubDesktopDir) {
        Write-Host "GitHub Desktop директория: $githubDesktopDir" -ForegroundColor Green
        Get-ChildItem -Path $githubDesktopDir -Force | ForEach-Object {
            $type = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
            Write-Host "   $type $($_.Name)" -ForegroundColor White
        }
    } else {
        Write-Host "GitHub Desktop директория не найдена" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Clear-GlobalGitConfig {
    Write-Host "Очистка глобальной конфигурации Git..." -ForegroundColor Yellow
    
    try {
        # Удаление основных настроек
        git config --global --unset user.name
        git config --global --unset user.email
        git config --global --unset credential.helper
        git config --global --unset credential.https://github.com.username
        
        Write-Host "Глобальная конфигурация Git очищена" -ForegroundColor Green
    } catch {
        Write-Host "Ошибка очистки глобальной конфигурации: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Clear-LocalGitConfig {
    Write-Host "Очистка локальной конфигурации Git..." -ForegroundColor Yellow
    
    try {
        # Удаление локальных настроек
        git config --local --unset user.name
        git config --local --unset user.email
        git config --local --unset credential.helper
        
        Write-Host "Локальная конфигурация Git очищена" -ForegroundColor Green
    } catch {
        Write-Host "Ошибка очистки локальной конфигурации: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Clear-SSHKeys {
    Write-Host "Очистка SSH ключей..." -ForegroundColor Yellow
    
    $sshDir = "$env:USERPROFILE\.ssh"
    if (Test-Path $sshDir) {
        try {
            # Создание резервной копии
            $backupDir = "$sshDir\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            
            # Копирование файлов в резервную копию
            Get-ChildItem -Path $sshDir -File | ForEach-Object {
                Copy-Item $_.FullName -Destination $backupDir
            }
            
            # Удаление всех файлов кроме backup
            Get-ChildItem -Path $sshDir -File | Remove-Item -Force
            Get-ChildItem -Path $sshDir -Directory | Where-Object { $_.Name -notlike "backup-*" } | Remove-Item -Recurse -Force
            
            Write-Host "SSH ключи очищены (резервная копия: $backupDir)" -ForegroundColor Green
        } catch {
            Write-Host "Ошибка очистки SSH ключей: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "SSH директория не найдена" -ForegroundColor Red
    }
}

function Clear-GitHubDesktopConfig {
    Write-Host "Очистка GitHub Desktop конфигурации..." -ForegroundColor Yellow
    
    $githubDesktopDir = "$env:APPDATA\GitHubDesktop"
    if (Test-Path $githubDesktopDir) {
        try {
            # Создание резервной копии
            $backupDir = "$githubDesktopDir-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item -Path $githubDesktopDir -Destination $backupDir -Recurse -Force
            
            # Удаление конфигурации
            Remove-Item -Path $githubDesktopDir -Recurse -Force
            
            Write-Host "GitHub Desktop конфигурация очищена (резервная копия: $backupDir)" -ForegroundColor Green
        } catch {
            Write-Host "Ошибка очистки GitHub Desktop: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "GitHub Desktop директория не найдена" -ForegroundColor Red
    }
}

function Clear-GitCredentials {
    Write-Host "Очистка сохранённых учётных данных..." -ForegroundColor Yellow
    
    try {
        # Очистка Windows Credential Manager
        cmdkey /list | ForEach-Object {
            if ($_ -match "git:https://github.com") {
                $target = $_.Split(':')[1].Trim()
                cmdkey /delete:$target
                Write-Host "   Удалён: $target" -ForegroundColor White
            }
        }
        
        Write-Host "Сохранённые учётные данные очищены" -ForegroundColor Green
    } catch {
        Write-Host "Ошибка очистки учётных данных: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-NewGitConfig {
    Write-Host "Настройка нового аккаунта Git..." -ForegroundColor Yellow
    
    $UserName = Read-Host "Введите новое имя пользователя"
    $UserEmail = Read-Host "Введите новый email"
    
    try {
        git config --global user.name $UserName
        git config --global user.email $UserEmail
        
        Write-Host "Новая конфигурация Git установлена:" -ForegroundColor Green
        Write-Host "   Имя: $UserName" -ForegroundColor White
        Write-Host "   Email: $UserEmail" -ForegroundColor White
    } catch {
        Write-Host "Ошибка настройки новой конфигурации: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-Menu {
    Write-Host ""
    Write-Host "Выберите действие:" -ForegroundColor Magenta
    Write-Host "1. Показать текущую конфигурацию"
    Write-Host "2. Очистить глобальную конфигурацию Git"
    Write-Host "3. Очистить локальную конфигурацию Git"
    Write-Host "4. Очистить SSH ключи"
    Write-Host "5. Очистить GitHub Desktop конфигурацию"
    Write-Host "6. Очистить сохранённые учётные данные"
    Write-Host "7. Полная очистка (все пункты)"
    Write-Host "8. Настроить новый аккаунт Git"
    Write-Host "9. Выход"
    Write-Host ""
}

# Основная логика
Write-Host "Анализ текущей конфигурации..." -ForegroundColor Yellow

# Показываем текущее состояние
Show-CurrentConfig
Show-SSHKeys
Show-GitHubDesktopConfig

if ($Force) {
    Write-Host "Принудительная очистка всех конфигураций..." -ForegroundColor Red
    
    Clear-GlobalGitConfig
    Clear-LocalGitConfig
    Clear-SSHKeys
    Clear-GitHubDesktopConfig
    Clear-GitCredentials
    
    Write-Host "Полная очистка завершена!" -ForegroundColor Green
} else {
    # Интерактивное меню
    do {
        Show-Menu
        $choice = Read-Host "Выберите действие (1-9)"
        
        switch ($choice) {
            "1" {
                Show-CurrentConfig
                Show-SSHKeys
                Show-GitHubDesktopConfig
            }
            "2" {
                $confirm = Read-Host "Очистить глобальную конфигурацию Git? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Clear-GlobalGitConfig
                }
            }
            "3" {
                $confirm = Read-Host "Очистить локальную конфигурацию Git? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Clear-LocalGitConfig
                }
            }
            "4" {
                $confirm = Read-Host "Очистить SSH ключи? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Clear-SSHKeys
                }
            }
            "5" {
                $confirm = Read-Host "Очистить GitHub Desktop конфигурацию? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Clear-GitHubDesktopConfig
                }
            }
            "6" {
                $confirm = Read-Host "Очистить сохранённые учётные данные? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Clear-GitCredentials
                }
            }
            "7" {
                $confirm = Read-Host "Выполнить полную очистку? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Clear-GlobalGitConfig
                    Clear-LocalGitConfig
                    Clear-SSHKeys
                    Clear-GitHubDesktopConfig
                    Clear-GitCredentials
                    Write-Host "Полная очистка завершена!" -ForegroundColor Green
                }
            }
            "8" {
                Set-NewGitConfig
            }
            "9" {
                Write-Host "До свидания!" -ForegroundColor Green
                break
            }
            default {
                Write-Host "Неверный выбор" -ForegroundColor Red
            }
        }
        
        if ($choice -ne "9") {
            Write-Host ""
            Read-Host "Нажмите Enter для продолжения"
        }
        
    } while ($choice -ne "9")
}

Write-Host ""
Write-Host "Очистка конфигурации завершена!" -ForegroundColor Green

