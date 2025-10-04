@echo off
echo 🚀 Настройка GitHub Pages для Leisure App
echo.

echo 📋 Инструкции:
echo 1. Создайте репозиторий на GitHub.com с именем "leisure_app"
echo 2. Скопируйте URL вашего репозитория
echo 3. Запустите этот скрипт снова и введите URL
echo.

set /p REPO_URL="Введите URL вашего GitHub репозитория (например: https://github.com/username/leisure_app.git): "

if "%REPO_URL%"=="" (
    echo ❌ URL не введен. Запустите скрипт снова.
    pause
    exit /b 1
)

echo.
echo 🔧 Настройка Git репозитория...
git remote add origin %REPO_URL%
git branch -M main

echo.
echo 📦 Копирование веб-файлов в корень...
if exist "build\web" (
    xcopy "build\web\*" "." /E /Y /Q
    echo ✅ Веб-файлы скопированы
) else (
    echo ⚠️ Папка build\web не найдена. Сначала соберите веб-версию:
    echo flutter build web -t lib/demo_app.dart
    pause
    exit /b 1
)

echo.
echo 📝 Добавление файлов в Git...
git add .

echo.
echo 💾 Создание коммита...
git commit -m "Add web version for GitHub Pages deployment"

echo.
echo 🚀 Загрузка на GitHub...
git push -u origin main

echo.
echo ✅ Готово! Ваше приложение будет доступно по адресу:
echo https://YOUR_USERNAME.github.io/leisure_app/
echo.
echo 📋 Следующие шаги:
echo 1. Перейдите в настройки репозитория на GitHub
echo 2. Включите GitHub Pages в разделе Settings ^> Pages
echo 3. Выберите источник "Deploy from a branch"
echo 4. Выберите ветку "main" и папку "/ (root)"
echo 5. Сохраните настройки
echo.
echo 🎉 Через 5-10 минут ваше приложение будет доступно!
pause
