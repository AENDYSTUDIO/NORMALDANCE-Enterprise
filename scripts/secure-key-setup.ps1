# NORMALDANCE Secure Key Setup
# Безопасная настройка SSH ключей и MCP для GitHub

param(
    [string]$KeyName = "normaldance-github",
    [string]$KeyType = "ed25519",
    [switch]$SetupMCP,
    [switch]$Interactive
)

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

function Test-GitHubCLI {
    try {
        $null = gh --version
        return $true
    }
    catch {
        Write-ColorLog "GitHub CLI не установлен" "Error"
        Write-ColorLog "Установите: https://cli.github.com/" "Info"
        return $false
    }
}

function Test-SSHAgent {
    try {
        $null = ssh-add -l
        return $true
    }
    catch {
        Write-ColorLog "SSH Agent не запущен" "Warning"
        return $false
    }
}

function New-SSHKey {
    param(
        [string]$Name,
        [string]$Type
    )
    
    Write-ColorLog "Генерация SSH ключа: $Name ($Type)" "Info"
    
    $keyPath = Join-Path $env:USERPROFILE ".ssh\$Name"
    $publicKeyPath = "$keyPath.pub"
    
    try {
        # Проверка существования ключа
        if (Test-Path $keyPath) {
            Write-ColorLog "Ключ уже существует: $keyPath" "Warning"
            $overwrite = Read-Host "Перезаписать? (y/N)"
            if ($overwrite -ne "y" -and $overwrite -ne "Y") {
                return $null
            }
        }
        
        # Генерация ключа
        $comment = "normaldance-github-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        ssh-keygen -t $Type -f $keyPath -C $comment -N '""'
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorLog "SSH ключ успешно сгенерирован" "Success"
            
            # Чтение публичного ключа
            $publicKey = Get-Content $publicKeyPath -Raw
            Write-ColorLog "Публичный ключ:" "Info"
            Write-Host $publicKey.Trim()
            
            return @{
                PrivateKeyPath = $keyPath
                PublicKeyPath = $publicKeyPath
                PublicKey = $publicKey.Trim()
            }
        } else {
            Write-ColorLog "Ошибка генерации SSH ключа" "Error"
            return $null
        }
    }
    catch {
        Write-ColorLog "Ошибка: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Add-KeyToGitHub {
    param(
        [string]$PublicKey,
        [string]$Title
    )
    
    Write-ColorLog "Добавление ключа в GitHub..." "Info"
    
    if (!(Test-GitHubCLI)) {
        return $false
    }
    
    try {
        # Проверка аутентификации
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorLog "Требуется аутентификация в GitHub CLI" "Warning"
            gh auth login
            if ($LASTEXITCODE -ne 0) {
                Write-ColorLog "Ошибка аутентификации" "Error"
                return $false
            }
        }
        
        # Добавление ключа
        $PublicKey | gh ssh-key add - -t $Title
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorLog "Ключ успешно добавлен в GitHub" "Success"
            return $true
        } else {
            Write-ColorLog "Ошибка добавления ключа в GitHub" "Error"
            return $false
        }
    }
    catch {
        Write-ColorLog "Ошибка: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-SSHConfig {
    param(
        [string]$KeyPath
    )
    
    Write-ColorLog "Настройка SSH конфигурации..." "Info"
    
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $configPath = Join-Path $sshDir "config"
    
    $configContent = @"
# NORMALDANCE GitHub Access Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile $KeyPath
    IdentitiesOnly yes
    AddKeysToAgent yes

Host github-normaldance
    HostName github.com
    User git
    IdentityFile $KeyPath
    IdentitiesOnly yes
    AddKeysToAgent yes
"@

    try {
        # Создание директории .ssh если не существует
        if (!(Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }
        
        # Добавление конфигурации
        if (Test-Path $configPath) {
            $existingConfig = Get-Content $configPath -Raw
            if ($existingConfig -notmatch "NORMALDANCE GitHub Access Configuration") {
                Add-Content -Path $configPath -Value "`n$configContent"
            }
        } else {
            Set-Content -Path $configPath -Value $configContent
        }
        
        Write-ColorLog "SSH конфигурация обновлена" "Success"
        return $true
    }
    catch {
        Write-ColorLog "Ошибка настройки SSH: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Set-MCPConfig {
    Write-ColorLog "Настройка MCP для GitHub..." "Info"
    
    $mcpConfigDir = Join-Path $env:USERPROFILE ".config\mcp"
    $mcpConfigPath = Join-Path $mcpConfigDir "config.json"
    
    $mcpConfig = @{
        mcpServers = @{
            github = @{
                command = "npx"
                args = @("-y", "@modelcontextprotocol/server-github")
                env = @{
                    GITHUB_PERSONAL_ACCESS_TOKEN = ""
                }
            }
        }
    }
    
    try {
        # Создание директории конфигурации
        if (!(Test-Path $mcpConfigDir)) {
            New-Item -ItemType Directory -Path $mcpConfigDir -Force | Out-Null
        }
        
        # Запись конфигурации
        $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $mcpConfigPath
        
        Write-ColorLog "MCP конфигурация создана" "Success"
        Write-ColorLog "Установите GITHUB_TOKEN в переменные окружения для полного доступа" "Info"
        return $true
    }
    catch {
        Write-ColorLog "Ошибка настройки MCP: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-GitHubConnection {
    Write-ColorLog "Проверка подключения к GitHub..." "Info"
    
    try {
        $result = ssh -T git@github.com 2>&1
        if ($result -match "successfully authenticated") {
            Write-ColorLog "Подключение к GitHub успешно" "Success"
            return $true
        } else {
            Write-ColorLog "Ошибка подключения к GitHub" "Error"
            Write-Host $result
            return $false
        }
    }
    catch {
        Write-ColorLog "Ошибка проверки подключения: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-InteractiveMenu {
    Write-Host "`n🎵 NORMALDANCE GitHub Access Setup" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "1. Генерировать SSH ключ"
    Write-Host "2. Добавить ключ в GitHub"
    Write-Host "3. Настроить MCP для GitHub"
    Write-Host "4. Проверить подключение к GitHub"
    Write-Host "5. Полная настройка (все пункты)"
    Write-Host "6. Выход"
    
    $choice = Read-Host "`nВыберите действие (1-6)"
    
    switch ($choice) {
        "1" {
            $keyName = Read-Host "Имя ключа (по умолчанию: normaldance-github)"
            if ([string]::IsNullOrEmpty($keyName)) { $keyName = "normaldance-github" }
            
            $keyType = Read-Host "Тип ключа (ed25519/rsa, по умолчанию: ed25519)"
            if ([string]::IsNullOrEmpty($keyType)) { $keyType = "ed25519" }
            
            $keyInfo = New-SSHKey -Name $keyName -Type $keyType
            if ($keyInfo) {
                Set-SSHConfig -KeyPath $keyInfo.PrivateKeyPath
            }
        }
        
        "2" {
            $publicKey = Read-Host "Введите публичный ключ"
            $title = Read-Host "Название ключа в GitHub (по умолчанию: NORMALDANCE-Access)"
            if ([string]::IsNullOrEmpty($title)) { $title = "NORMALDANCE-Access" }
            
            Add-KeyToGitHub -PublicKey $publicKey -Title $title
        }
        
        "3" {
            Set-MCPConfig
        }
        
        "4" {
            Test-GitHubConnection
        }
        
        "5" {
            Write-ColorLog "Запуск полной настройки..." "Info"
            
            $keyInfo = New-SSHKey -Name $KeyName -Type $KeyType
            if ($keyInfo) {
                Set-SSHConfig -KeyPath $keyInfo.PrivateKeyPath
                Add-KeyToGitHub -PublicKey $keyInfo.PublicKey -Title "NORMALDANCE-Access"
                Set-MCPConfig
                Test-GitHubConnection
            }
        }
        
        "6" {
            Write-ColorLog "До свидания!" "Success"
            return
        }
        
        default {
            Write-ColorLog "Неверный выбор" "Error"
        }
    }
}

# Основная логика
Write-Host "🔐 NORMALDANCE Secure Key Setup" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

if ($Interactive) {
    Show-InteractiveMenu
} else {
    # Автоматическая настройка
    Write-ColorLog "Автоматическая настройка SSH ключа..." "Info"
    
    $keyInfo = New-SSHKey -Name $KeyName -Type $KeyType
    if ($keyInfo) {
        Set-SSHConfig -KeyPath $keyInfo.PrivateKeyPath
        
        $addToGitHub = Read-Host "Добавить ключ в GitHub? (y/N)"
        if ($addToGitHub -eq "y" -or $addToGitHub -eq "Y") {
            Add-KeyToGitHub -PublicKey $keyInfo.PublicKey -Title "NORMALDANCE-Access"
        }
        
        if ($SetupMCP) {
            Set-MCPConfig
        }
        
        Test-GitHubConnection
    }
}

