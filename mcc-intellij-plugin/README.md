# MCC Port Forwarder - IntelliJ IDEA Plugin

IntelliJ IDEA plugin для управления port forwarding соединениями прямо из IDE.

## 🎯 Функции

- ✅ Управление сервисами и хостами
- ✅ Множественные порты на хост
- ✅ Поддержка мульти-дата-центров
- ✅ Отслеживание статуса в реальном времени
- ✅ Старт/стоп отдельных портов или целых сервисов
- ✅ Авто-повтор при ошибках
- ✅ Убийство блокирующих процессов
- ✅ Импорт/экспорт конфигурации
- ✅ Детальные логи по каждому порту

## 📊 Индикаторы статуса

- 🔵 **Connecting** - Процесс запущен
- 🟡 **Authenticating** - Аутентификация
- 🟢 **Ready** - Соединение установлено
- 🔴 **Error** - Ошибка подключения
- 🟠 **Timeout** - Превышен таймаут
- 🟠 **Port Busy** - Порт занят
- 🔄 **Restarting** - Перезапуск
- 🟣 **Disconnected** - Соединение разорвано

## 🚀 Сборка плагина

### Требования

- JDK 17 или новее
- Gradle 8.x (включен wrapper)

### Сборка

```bash
cd mcc-intellij-plugin

# Сборка плагина
./gradlew buildPlugin

# Результат будет в:
# build/distributions/mcc-intellij-plugin-1.0.0.zip
```

**⏱️ Первая сборка:**
- При первом запуске Gradle автоматически загрузит:
  - Gradle 8.5 (~100 MB)
  - JDK 17 через foojay-resolver (~200 MB)
  - Зависимости IntelliJ Platform (~800 MB)
- Полная сборка займет 3-5 минут
- Последующие сборки будут быстрее (~30 секунд)

## 📦 Установка плагина (без маркетплейса)

### Вариант 1: Установка из ZIP файла

1. **Соберите плагин:**
   ```bash
   cd mcc-intellij-plugin
   ./gradlew buildPlugin
   ```

2. **Откройте IntelliJ IDEA**

3. **Перейдите в Settings/Preferences:**
   - **macOS:** `IntelliJ IDEA → Settings` или `Cmd + ,`
   - **Windows/Linux:** `File → Settings` или `Ctrl + Alt + S`

4. **Установите плагин:**
   - Выберите `Plugins` в левом меню
   - Нажмите на иконку ⚙️ (шестеренка) → `Install Plugin from Disk...`
   - Выберите файл `build/distributions/mcc-intellij-plugin-1.0.0.zip`
   - Нажмите `OK`

5. **Перезапустите IDE**

### Вариант 2: Запуск в режиме разработки

```bash
cd mcc-intellij-plugin

# Запустит новый экземпляр IntelliJ с установленным плагином
./gradlew runIde
```

### Вариант 3: Установка в локальный репозиторий

```bash
cd mcc-intellij-plugin

# Публикация в локальный репозиторий
./gradlew publishPlugin

# Плагин будет доступен в:
# build/distributions/
```

## 🎨 Использование

### 1. Открыть Tool Window

После установки:
- Справа в IDE появится вкладка **MCC Port Forwarder**
- Или: `View → Tool Windows → MCC Port Forwarder`

### 2. Настройка

`Settings → Tools → MCC Port Forwarder`

Настройте:
- Port Forward Command (по умолчанию: `/usr/local/bin/mcc tp-port-forward`)
- Login Command
- Logout Command
- Auto-retry параметры
- Дата-центры

### 3. Добавление сервисов

1. В Tool Window нажмите `Add Service`
2. Введите имя сервиса
3. Добавьте хосты с портами
4. Для мульти-DC: используйте `{location}` в hostname (например, `db.{location}.example.com`)

### 4. Управление портами

- **Start/Stop** - кнопки у каждого порта
- **Start All** - запустить все сервисы
- **Stop All** - остановить все
- **Клик правой кнопкой** - контекстное меню с дополнительными действиями

### 5. Логи

- Клик на порт → показать логи
- Автоматическое обновление в реальном времени

## 🛠️ Разработка

### Структура проекта

```
mcc-intellij-plugin/
├── build.gradle.kts          # Конфигурация сборки
├── settings.gradle.kts        # Настройки Gradle
├── gradle.properties          # Свойства плагина
└── src/
    └── main/
        ├── kotlin/
        │   └── com/mcc/portforwarder/
        │       ├── models/            # Модели данных
        │       ├── services/          # Бизнес-логика
        │       ├── toolwindow/        # UI Tool Window
        │       ├── settings/          # Настройки
        │       └── actions/           # Actions
        └── resources/
            └── META-INF/
                └── plugin.xml         # Манифест плагина
```

### Полезные команды

```bash
# Сборка
./gradlew build

# Сборка плагина (ZIP)
./gradlew buildPlugin

# Запуск в dev режиме
./gradlew runIde

# Проверка совместимости
./gradlew verifyPlugin

# Очистка
./gradlew clean
```

### Обновление зависимостей

Редактируйте `build.gradle.kts`:

```kotlin
intellij {
    version.set("2023.3")  // Версия IDEA
    type.set("IC")         // IC = Community, IU = Ultimate
}
```

## 🐛 Отладка

### Включить логи плагина

1. `Help → Diagnostic Tools → Debug Log Settings`
2. Добавить: `#com.mcc.portforwarder`
3. Логи в: `Help → Show Log in Finder/Explorer`

### Просмотр логов в реальном времени

```bash
# macOS
tail -f ~/Library/Logs/JetBrains/IntelliJIdea*/idea.log

# Linux
tail -f ~/.local/share/JetBrains/IntelliJIdea*/log/idea.log

# Windows
# %USERPROFILE%\AppData\Local\JetBrains\IntelliJIdea*\log\idea.log
```

## 📋 Требования

- IntelliJ IDEA 2023.3 или новее
- JDK 17+
- macOS 13.0+ / Linux / Windows 10+

## 🔄 Обновление плагина

1. Соберите новую версию
2. `Settings → Plugins`
3. Найдите **MCC Port Forwarder** → `⚙️ → Uninstall`
4. Перезапустите IDE
5. Установите новую версию

## 📝 Конфигурация

Все настройки хранятся в:
- **macOS:** `~/Library/Application Support/JetBrains/IntelliJIdea*/options/MCCPortForwarder.xml`
- **Linux:** `~/.config/JetBrains/IntelliJIdea*/options/MCCPortForwarder.xml`
- **Windows:** `%APPDATA%\JetBrains\IntelliJIdea*\options\MCCPortForwarder.xml`

## 🤝 Совместимость

| IDEA Version | Plugin Version | Supported |
|--------------|----------------|-----------|
| 2023.3+      | 1.0.0         | ✅        |
| 2024.1+      | 1.0.0         | ✅        |

## 📄 Лицензия

См. LICENSE файл

## 🆘 Поддержка

При проблемах:
1. Проверьте логи IDE
2. Убедитесь что `mcc` команда доступна
3. Проверьте PATH в системе
4. Создайте issue в репозитории

