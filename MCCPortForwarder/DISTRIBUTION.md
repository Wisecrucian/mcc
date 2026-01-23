# Распространение приложения MCCPortForwarder

## Быстрый старт

### Создать дистрибутив одной командой:
```bash
make dist
```

Эта команда:
1. Очистит предыдущие сборки
2. Соберёт Release версию
3. Создаст `MCCPortForwarder.zip` для распространения

## Пошаговые инструкции

### 1. Сборка Release версии

```bash
cd /Users/max/mcc/MCCPortForwarder
make build
```

Готовое приложение будет в:
```
./build/Build/Products/Release/MCCPortForwarder.app
```

### 2. Создание архива для распространения

```bash
make archive
```

Создаст файл `MCCPortForwarder.zip` в корне проекта.

### 3. Проверка информации о приложении

```bash
make info
```

Покажет:
- Версию приложения
- Bundle ID
- Размер файла
- Путь к .app

## Распространение

### Вариант 1: ZIP архив (рекомендуется)

```bash
make dist
```

**Отправьте файл** `MCCPortForwarder.zip` пользователям.

**Инструкция для пользователя:**
1. Скачайте `MCCPortForwarder.zip`
2. Распакуйте архив (двойной клик)
3. Перетащите `MCCPortForwarder.app` в папку `/Applications/`
4. Запустите из Applications или через Spotlight (Cmd+Space)

### Вариант 2: Прямая копия .app

Скопируйте папку приложения:
```bash
cp -R ./build/Build/Products/Release/MCCPortForwarder.app ~/Desktop/
```

Отправьте папку `MCCPortForwarder.app` (как есть, это директория).

### Вариант 3: Установка на локальный Mac

```bash
make install
```

Установит приложение в `/Applications/` на текущем Mac.

## Размер приложения

Типичный размер: **~2-5 MB**

## Требования для пользователя

- **macOS**: 13.0 (Ventura) или новее
- **Архитектура**: Apple Silicon (ARM64) или Intel (нужно пересобрать)
- **Права**: Нет необходимости в admin правах
- **Зависимости**: Должен быть установлен CLI `mcc` или другая настроенная команда

## Code Signing (Подпись кода)

### Текущий статус
Приложение собирается **без подписи** (ad-hoc signing).

### Первый запуск на другом Mac

Пользователю нужно будет:

1. **При первом запуске**, если macOS блокирует:
   ```
   "MCCPortForwarder.app" cannot be opened because it is from an unidentified developer
   ```

2. **Решение - вариант A** (через System Settings):
   - Откройте **System Settings** → **Privacy & Security**
   - Прокрутите вниз до раздела "Security"
   - Нажмите **"Open Anyway"** рядом с MCCPortForwarder

3. **Решение - вариант B** (через Terminal):
   ```bash
   xattr -cr /Applications/MCCPortForwarder.app
   ```

### Добавление настоящей подписи (опционально)

Если у вас есть Apple Developer Account ($99/год):

1. Получите сертификат "Developer ID Application"
2. Измените `project.yml`:
   ```yaml
   settings:
     CODE_SIGN_IDENTITY: "Developer ID Application: Your Name (TEAM_ID)"
     DEVELOPMENT_TEAM: YOUR_TEAM_ID
   ```
3. Пересгенерируйте проект: `make setup`
4. Соберите: `make build`

### Нотаризация (для публичного распространения)

Для распространения вне Mac App Store:
```bash
# После сборки с Developer ID
xcrun notarytool submit MCCPortForwarder.zip \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

## Архитектуры

### Текущая сборка
- **ARM64** (Apple Silicon): ✅ По умолчанию
- **x86_64** (Intel): ❌ Не включен

### Universal Binary (для обоих)

Измените `project.yml`:
```yaml
settings:
  ARCHS: "arm64 x86_64"
```

Затем:
```bash
make setup
make dist
```

Размер файла увеличится примерно в 2 раза.

## Структура файлов

### Что включено в .app:
```
MCCPortForwarder.app/
├── Contents/
│   ├── Info.plist           # Метаданные приложения
│   ├── MacOS/
│   │   └── MCCPortForwarder # Исполняемый файл
│   ├── Resources/           # Ресурсы (иконки и т.д.)
│   └── _CodeSignature/      # Подпись (если есть)
```

### Размеры компонентов:
- Исполняемый файл: ~1-2 MB
- Ресурсы: ~100-500 KB
- Frameworks: нет (используется системный SwiftUI)

## CI/CD автоматизация

### GitHub Actions пример:

```yaml
name: Build Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v3
      
      - name: Install XcodeGen
        run: brew install xcodegen
      
      - name: Build
        run: make dist
      
      - name: Upload Release
        uses: actions/upload-artifact@v3
        with:
          name: MCCPortForwarder
          path: MCCPortForwarder.zip
```

## Troubleshooting

### Ошибка при сборке
```bash
make clean
make setup
make build
```

### Проверка архива
```bash
unzip -l MCCPortForwarder.zip
```

### Тестирование на чистой системе
```bash
# Симуляция первого запуска
xattr -w com.apple.quarantine "0083;$(date +%s);Safari" MCCPortForwarder.app
open MCCPortForwarder.app
```

## Альтернативные методы распространения

### 1. Homebrew Cask (для опытных пользователей)
Создайте cask формулу для установки через `brew install --cask`

### 2. DMG образ (визуально привлекательно)
```bash
# Создание DMG
hdiutil create -volname "MCC Port Forwarder" \
  -srcfolder ./build/Build/Products/Release/MCCPortForwarder.app \
  -ov -format UDZO MCCPortForwarder.dmg
```

### 3. PKG installer (для корпоративного распространения)
```bash
productbuild --component ./build/Build/Products/Release/MCCPortForwarder.app \
  /Applications MCCPortForwarder.pkg
```

## Рекомендации

✅ **Используйте**: `make dist` для простого распространения
✅ **Включите**: Инструкцию для пользователя о первом запуске
✅ **Тестируйте**: На другом Mac перед распространением
✅ **Версионируйте**: Обновляйте версию в Info.plist при изменениях

❌ **Не включайте**: Debug символы в Release
❌ **Не отправляйте**: Папку `build/` целиком
❌ **Не забывайте**: Про системные требования в документации

## Быстрая справка команд

```bash
# Разработка
make run          # Запуск для тестирования

# Релиз
make dist         # Полный цикл сборки дистрибутива
make build        # Только сборка Release
make archive      # Только создание ZIP
make install      # Установка на текущий Mac

# Утилиты
make info         # Информация о сборке
make clean        # Очистка
make help         # Помощь
```

## Версионирование

При выпуске новой версии обновите `project.yml`:
```yaml
settings:
  MARKETING_VERSION: "2.0.0"
  CURRENT_PROJECT_VERSION: "42"
```

Затем:
```bash
make setup  # Применить изменения
make dist   # Собрать новую версию
```

