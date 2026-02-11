# MCC Port Forwarder - IntelliJ IDEA Plugin

## ✨ Правильная реализация с IntelliJ Platform компонентами

### Что использовано

#### ✅ DialogWrapper вместо JDialog
- `AddServiceDialog` - добавление/редактирование сервисов
- `AddHostDialog` - добавление/редактирование хостов с datacenter configuration
- `SettingsDialog` - настройки с импортом/экспортом
- `LogViewerDialog` - просмотр логов

#### ✅ AnAction вместо JButton
- `LoginAction` - аутентификация
- `LogoutAction` - выход
- `SettingsAction` - открыть настройки
- `AddServiceAction` - добавить сервис

#### ✅ UI DSL вместо ручного layout
Все диалоги используют `panel { }` DSL:
```kotlin
panel {
    row("Name:") {
        textField()
            .bindText(::name)
            .columns(30)
    }
}
```

#### ✅ Notifications вместо JOptionPane
```kotlin
Notifications.Bus.notify(
    Notification("MCC", "Success", "...", NotificationType.INFORMATION)
)
```

#### ✅ OSProcessHandler вместо Process
- Правильное управление процессами
- Real-time log streaming
- Автоматическое управление lifecycle

#### ✅ PersistentStateComponent
- `MCCSettings` - настройки приложения
- `MCCStorage` - хранение конфигураций

#### ✅ Project Service
- `MCCService` - основная бизнес-логика
- Правильная регистрация через `@Service`

### Структура

```
mcc-intellij-plugin/
├── models/              # Data classes
│   └── Models.kt       # Service, Host, LocationMapping, ProcessState
├── services/            # Правильно зарегистрированные @Service
│   ├── MCCSettings.kt  # Settings with PersistentStateComponent
│   ├── MCCStorage.kt   # Storage with PersistentStateComponent
│   └── MCCService.kt   # Main business logic
├── actions/             # AnAction для toolbar
│   └── ToolbarActions.kt
├── dialogs/             # DialogWrapper диалоги
│   ├── AddServiceDialog.kt
│   ├── AddHostDialog.kt
│   ├── SettingsDialog.kt
│   └── LogViewerDialog.kt
└── toolwindow/          # Tool Window
    ├── MCCToolWindowFactory.kt
    └── MCCToolWindowPanel.kt
```

### Функциональность

✅ Иерархическое управление сервисами
✅ Multi-datacenter хосты
✅ Real-time мониторинг процессов
✅ Импорт/экспорт конфигураций (без UUID)
✅ Автоматический retry при ошибках
✅ Просмотр логов
✅ Аутентификация
✅ Kill process на занятом порту

### Сборка

```bash
./gradlew buildPlugin
```

Результат: `build/distributions/mcc-intellij-plugin-1.0.0.zip`

### Установка

1. IntelliJ IDEA → Settings → Plugins
2. ⚙️ → Install Plugin from Disk...
3. Выбрать `build/distributions/mcc-intellij-plugin-1.0.0.zip`
4. Restart IDE

### Использование

1. View → Tool Windows → MCCPortForwarder
2. Login для аутентификации
3. Settings для настройки команд и datacenter'ов
4. Add Service для создания структуры
5. Выбор элемента в дереве → динамические кнопки внизу

### Требования

- IntelliJ IDEA 2024.2+ (build 242+)
- JDK 21 для сборки
- macOS/Linux (для команд lsof, kill)

### Отличия от первой версии

❌ **Было (плохо)**:
- Чистый Swing (JDialog, JButton, JPanel)
- Ручной layout (GridBagLayout, BorderLayout)
- JOptionPane для уведомлений
- Простые coroutines для процессов
- Ручное управление темами

✅ **Стало (правильно)**:
- IntelliJ Platform компоненты (DialogWrapper, AnAction)
- UI DSL для layout
- Notifications API
- OSProcessHandler для процессов
- Автоматические темы IDE
- Правильная интеграция с IDE

### Преимущества

🚀 Более стабильный
🎨 Правильные темы (dark/light)
⌨️ Поддержка shortcuts
🔔 Нативные уведомления
📦 Меньше кода
✨ Лучшая интеграция с IDE
