@echo off
echo.
echo 🔑 NORMALDANCE SSH Key Generator
echo ===============================
echo.

REM Проверка Git
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Git не установлен. Установите Git перед продолжением.
    pause
    exit /b 1
)
echo ✅ Git установлен

REM Генерация SSH ключа
set KEY_NAME=normaldance-github
set KEY_PATH=%USERPROFILE%\.ssh\%KEY_NAME%
set PUBLIC_KEY_PATH=%KEY_PATH%.pub

echo.
echo 🔑 Генерация SSH ключа...
echo.

REM Создание директории .ssh если не существует
if not exist "%USERPROFILE%\.ssh" (
    mkdir "%USERPROFILE%\.ssh"
    echo 📁 Создана директория: %USERPROFILE%\.ssh
)

REM Проверка существования ключа
if exist "%KEY_PATH%" (
    echo ⚠️  SSH ключ уже существует: %KEY_PATH%
    set /p OVERWRITE="Перезаписать? (y/N): "
    if /i not "%OVERWRITE%"=="y" (
        echo Пропуск генерации SSH ключа
        pause
        exit /b 0
    )
)

REM Генерация ключа
set COMMENT=normaldance-github-%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set COMMENT=%COMMENT: =0%

echo 🔧 Генерация ключа с комментарием: %COMMENT%

ssh-keygen -t ed25519 -f "%KEY_PATH%" -C "%COMMENT%" -N ""

if %errorlevel% equ 0 (
    echo ✅ SSH ключ успешно сгенерирован
    
    REM Чтение публичного ключа
    if exist "%PUBLIC_KEY_PATH%" (
        echo.
        echo 📋 Публичный ключ:
        echo ==================
        type "%PUBLIC_KEY_PATH%"
        echo ==================
        echo.
        
        echo 🔧 Инструкции по добавлению ключа в GitHub:
        echo 1. Перейдите в GitHub Settings ^> SSH and GPG keys
        echo 2. Нажмите 'New SSH key'
        echo 3. Введите название: NORMALDANCE-Access
        echo 4. Скопируйте публичный ключ выше
        echo 5. Нажмите 'Add SSH key'
        echo.
        
        REM Проверка GitHub CLI
        gh --version >nul 2>&1
        if %errorlevel% equ 0 (
            set /p AUTO_ADD="🔐 GitHub CLI обнаружен. Добавить ключ автоматически? (y/N): "
            if /i "%AUTO_ADD%"=="y" (
                echo 🔐 Аутентификация в GitHub CLI...
                gh auth login
                
                if %errorlevel% equ 0 (
                    type "%PUBLIC_KEY_PATH%" | gh ssh-key add - -t "NORMALDANCE-Access"
                    if %errorlevel% equ 0 (
                        echo ✅ Ключ успешно добавлен в GitHub
                    ) else (
                        echo ❌ Ошибка добавления ключа в GitHub
                    )
                )
            )
        ) else (
            echo ℹ️  GitHub CLI не установлен. Добавьте ключ вручную по инструкциям выше.
        )
        
        REM Настройка SSH конфигурации
        echo.
        echo ⚙️  Настройка SSH конфигурации...
        
        set CONFIG_PATH=%USERPROFILE%\.ssh\config
        
        if exist "%CONFIG_PATH%" (
            findstr /C:"NORMALDANCE" "%CONFIG_PATH%" >nul
            if %errorlevel% neq 0 (
                echo. >> "%CONFIG_PATH%"
                echo # NORMALDANCE GitHub Access Configuration >> "%CONFIG_PATH%"
                echo Host github.com >> "%CONFIG_PATH%"
                echo     HostName github.com >> "%CONFIG_PATH%"
                echo     User git >> "%CONFIG_PATH%"
                echo     IdentityFile %KEY_PATH% >> "%CONFIG_PATH%"
                echo     IdentitiesOnly yes >> "%CONFIG_PATH%"
                echo     AddKeysToAgent yes >> "%CONFIG_PATH%"
                echo. >> "%CONFIG_PATH%"
                echo Host github-normaldance >> "%CONFIG_PATH%"
                echo     HostName github.com >> "%CONFIG_PATH%"
                echo     User git >> "%CONFIG_PATH%"
                echo     IdentityFile %KEY_PATH% >> "%CONFIG_PATH%"
                echo     IdentitiesOnly yes >> "%CONFIG_PATH%"
                echo     AddKeysToAgent yes >> "%CONFIG_PATH%"
                echo ✅ SSH конфигурация обновлена
            ) else (
                echo ✅ SSH конфигурация уже настроена
            )
        ) else (
            echo # NORMALDANCE GitHub Access Configuration > "%CONFIG_PATH%"
            echo Host github.com >> "%CONFIG_PATH%"
            echo     HostName github.com >> "%CONFIG_PATH%"
            echo     User git >> "%CONFIG_PATH%"
            echo     IdentityFile %KEY_PATH% >> "%CONFIG_PATH%"
            echo     IdentitiesOnly yes >> "%CONFIG_PATH%"
            echo     AddKeysToAgent yes >> "%CONFIG_PATH%"
            echo. >> "%CONFIG_PATH%"
            echo Host github-normaldance >> "%CONFIG_PATH%"
            echo     HostName github.com >> "%CONFIG_PATH%"
            echo     User git >> "%CONFIG_PATH%"
            echo     IdentityFile %KEY_PATH% >> "%CONFIG_PATH%"
            echo     IdentitiesOnly yes >> "%CONFIG_PATH%"
            echo     AddKeysToAgent yes >> "%CONFIG_PATH%"
            echo ✅ SSH конфигурация создана
        )
        
        REM Проверка подключения
        echo.
        echo 🔍 Проверка подключения к GitHub...
        
        ssh -T git@github.com 2>&1 | findstr "successfully authenticated" >nul
        if %errorlevel% equ 0 (
            echo ✅ Подключение к GitHub работает
        ) else (
            echo ⚠️  SSH подключение к GitHub не настроено
            echo Убедитесь, что ключ добавлен в GitHub
        )
        
    ) else (
        echo ❌ Ошибка чтения публичного ключа
    )
) else (
    echo ❌ Ошибка генерации SSH ключа
)

echo.
echo 🎉 Генерация SSH ключа завершена!
echo.
echo 📚 Дополнительная информация:
echo • Документация: docs/SECURITY_WORKFLOW.md
echo • Приватный ключ: %KEY_PATH%
echo • Публичный ключ: %PUBLIC_KEY_PATH%
echo.
pause

