# NORMALDANCE Git Configuration Cleaner
# Полная очистка старых Git и GitHub конфигураций

param(
    [switch]$Force,
    [string]$NewUserName = "",
    [string]$NewUserEmail = ""
)

Write-Host "🧹 NORMALDANCE Git Configuration Cleaner" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Цвета для вывода
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Cyan = "Cyan"

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
        default { Write-Host $Message }
    }
}

function Show-CurrentConfig {
    Write-ColorLog "Текущая конфигурация Git:" "Info"
    Write-Host ""
    
    # Глобальная конфигурация
    Write-Host "🌐 Глобальная конфигурация:" -ForegroundColor Yellow
    try {
        git config --global --list | ForEach-Object { Write-Host "   $_" }
    } catch {
        Write-ColorLog "Ошибка чтения глобальной конфигурации" "Error"
    }
    
    Write-Host ""
    
    # Локальная конфигурация
    Write-Host "📁 Локальная конфигурация:" -ForegroundColor Yellow
    try {
        git config --local --list | ForEach-Object { Write-Host "   $_" }
    } catch {
        Write-ColorLog "Ошибка чтения локальной конфигурации" "Error"
    }
    
    Write-Host ""
}

function Show-SSHKeys {
    Write-ColorLog "SSH ключи:" "Info"
    Write-Host ""
    
    $sshDir = "$env:USERPROFILE\.ssh"
    if (Test-Path $sshDir) {
        Write-Host "📁 SSH директория: $sshDir" -ForegroundColor Yellow
        Get-ChildItem -Path $sshDir -Force | ForEach-Object {
            $icon = if ($_.PSIsContainer) { "📁" } else { "📄" }
            Write-Host "   $icon $($_.Name) ($($_.Length) bytes)" -ForegroundColor White
        }
    } else {
        Write-ColorLog "SSH директория не найдена" "Warning"
    }
    
    Write-Host ""
}

function Show-GitHubDesktopConfig {
    Write-ColorLog "GitHub Desktop конфигурация:" "Info"
    Write-Host ""
    
    $githubDesktopDir = "$env:APPDATA\GitHubDesktop"
    if (Test-Path $githubDesktopDir) {
        Write-Host "📁 GitHub Desktop директория: $githubDesktopDir" -ForegroundColor Yellow
        Get-ChildItem -Path $githubDesktopDir -Force | ForEach-Object {
            $icon = if ($_.PSIsContainer) { "📁" } else { "📄" }
            Write-Host "   $icon $($_.Name)" -ForegroundColor White
        }
    } else {
        Write-ColorLog "GitHub Desktop директория не найдена" "Warning"
    }
    
    Write-Host ""
}

function Clear-GlobalGitConfig {
    Write-ColorLog "Очистка глобальной конфигурации Git..." "Info"
    
    try {
        # Удаление основных настроек
        git config --global --unset user.name
        git config --global --unset user.email
        git config --global --unset credential.helper
        git config --global --unset credential.https://github.com.username
        
        # Удаление всех настроек
        $configKeys = git config --global --list | ForEach-Object { $_.Split('=')[0] }
        foreach ($key in $configKeys) {
            git config --global --unset $key
        }
        
        Write-ColorLog "Глобальная конфигурация Git очищена" "Success"
    } catch {
        Write-ColorLog "Ошибка очистки глобальной конфигурации: $($_.Exception.Message)" "Error"
    }
}

function Clear-LocalGitConfig {
    Write-ColorLog "Очистка локальной конфигурации Git..." "Info"
    
    try {
        # Удаление локальных настроек
        git config --local --unset user.name
        git config --local --unset user.email
        git config --local --unset credential.helper
        
        Write-ColorLog "Локальная конфигурация Git очищена" "Success"
    } catch {
        Write-ColorLog "Ошибка очистки локальной конфигурации: $($_.Exception.Message)" "Error"
    }
}

function Clear-SSHKeys {
    Write-ColorLog "Очистка SSH ключей..." "Info"
    
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
            
            Write-ColorLog "SSH ключи очищены (резервная копия: $backupDir)" "Success"
        } catch {
            Write-ColorLog "Ошибка очистки SSH ключей: $($_.Exception.Message)" "Error"
        }
    } else {
        Write-ColorLog "SSH директория не найдена" "Warning"
    }
}

function Clear-GitHubDesktopConfig {
    Write-ColorLog "Очистка GitHub Desktop конфигурации..." "Info"
    
    $githubDesktopDir = "$env:APPDATA\GitHubDesktop"
    if (Test-Path $githubDesktopDir) {
        try {
            # Создание резервной копии
            $backupDir = "$githubDesktopDir-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item -Path $githubDesktopDir -Destination $backupDir -Recurse -Force
            
            # Удаление конфигурации
            Remove-Item -Path $githubDesktopDir -Recurse -Force
            
            Write-ColorLog "GitHub Desktop конфигурация очищена (резервная копия: $backupDir)" "Success"
        } catch {
            Write-ColorLog "Ошибка очистки GitHub Desktop: $($_.Exception.Message)" "Error"
        }
    } else {
        Write-ColorLog "GitHub Desktop директория не найдена" "Warning"
    }
}

function Clear-GitCredentials {
    Write-ColorLog "Очистка сохранённых учётных данных..." "Info"
    
    try {
        # Очистка Windows Credential Manager
        cmdkey /list | ForEach-Object {
            if ($_ -match "git:https://github.com") {
                $target = $_.Split(':')[1].Trim()
                cmdkey /delete:$target
                Write-Host "   Удалён: $target" -ForegroundColor White
            }
        }
        
        Write-ColorLog "Сохранённые учётные данные очищены" "Success"
    } catch {
        Write-ColorLog "Ошибка очистки учётных данных: $($_.Exception.Message)" "Error"
    }
}

function Set-NewGitConfig {
    param(
        [string]$UserName,
        [string]$UserEmail
    )
    
    if ([string]::IsNullOrEmpty($UserName) -or [string]::IsNullOrEmpty($UserEmail)) {
        Write-ColorLog "Настройка нового аккаунта Git..." "Info"
        
        $UserName = Read-Host "Введите новое имя пользователя"
        $UserEmail = Read-Host "Введите новый email"
    }
    
    try {
        git config --global user.name $UserName
        git config --global user.email $UserEmail
        
        Write-ColorLog "Новая конфигурация Git установлена:" "Success"
        Write-Host "   Имя: $UserName" -ForegroundColor White
        Write-Host "   Email: $UserEmail" -ForegroundColor White
    } catch {
        Write-ColorLog "Ошибка настройки новой конфигурации: $($_.Exception.Message)" "Error"
    }
}

function Show-Menu {
    Write-Host ""
    Write-Host "🎯 Выберите действие:" -ForegroundColor Magenta
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
Write-ColorLog "Анализ текущей конфигурации..." "Info"

# Показываем текущее состояние
Show-CurrentConfig
Show-SSHKeys
Show-GitHubDesktopConfig

if ($Force) {
    Write-ColorLog "Принудительная очистка всех конфигураций..." "Warning"
    
    Clear-GlobalGitConfig
    Clear-LocalGitConfig
    Clear-SSHKeys
    Clear-GitHubDesktopConfig
    Clear-GitCredentials
    
    if (![string]::IsNullOrEmpty($NewUserName) -and ![string]::IsNullOrEmpty($NewUserEmail)) {
        Set-NewGitConfig -UserName $NewUserName -UserEmail $NewUserEmail
    }
    
    Write-ColorLog "Полная очистка завершена!" "Success"
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
                    Write-ColorLog "Полная очистка завершена!" "Success"
                }
            }
            "8" {
                Set-NewGitConfig
            }
            "9" {
                Write-ColorLog "До свидания!" "Success"
                break
            }
            default {
                Write-ColorLog "Неверный выбор" "Error"
            }
        }
        
        if ($choice -ne "9") {
            Write-Host ""
            Read-Host "Нажмите Enter для продолжения"
        }
        
    } while ($choice -ne "9")
}

Write-Host ""
Write-ColorLog "Очистка конфигурации завершена!" "Success"

