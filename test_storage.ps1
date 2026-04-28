Write-Host "🔍 Проверяем Storage..." -ForegroundColor Cyan

# 1. Смотрим текущие правила
Write-Host "📄 Storage правила:" -ForegroundColor Yellow
Get-Content storage.rules

# 2. Тестовая команда для проверки Storage
Write-Host "🧪 Тестируем доступ..." -ForegroundColor Green
echo "test file" > test.txt

# 3. Попробуй открыть Storage в браузере
Start-Process "https://console.firebase.google.com/project/foviox-2f61b/storage/files"

Write-Host "✅ Открой ссылку выше и проверь:" -ForegroundColor Cyan
Write-Host "1. Есть ли папка 'avatars/'" -ForegroundColor Yellow
Write-Host "2. Нажми 'Правила' и проверь что написано" -ForegroundColor Yellow
Write-Host "3. Попробуй вручную загрузить файл" -ForegroundColor Yellow
