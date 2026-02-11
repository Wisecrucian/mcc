# Промпт для реализации плагина IntelliJ IDEA "MCC Port Forwarder"

## Задача
Реализовать плагин для IntelliJ IDEA, который полностью дублирует функциональность существующего SwiftUI приложения MCC Port Forwarder с точным воспроизведением визуальных элементов и структуры.

## 📐 Визуальная структура (точное соответствие)

### 1. Главное окно (Tool Window)
```
┌─────────────────────────────────────────────────────┐
│ ⚙️ [MCC Port Forwarder]         [⚙️] [➕] [✖️]      │
├─────────────────────────────────────────────────────┤
│                                                      │
│ ▶ 🟢 Service Name            3 hosts    ✏️ Start 🗑│
│   ├─ ▶ 🟢 Host: postgres-master      2 map... 📋 ✏️│
│   │   │ hostname: db.{location}.ru                  │
│   │   ├─ 🟢 5432 → 9999  Running   📋 ❌ ▶         │
│   │   └─ 🟢 5432 → 10000 Running   📋 ❌ ▶         │
│   │                                                  │
│   ├─ 📋 Host: redis-cache            1 map... 📋 ✏️│
│   │   │ hostname: redis.prod.com                    │
│   │   └─ 🟢 6379 → 6379  Running   📋 ❌ ▶         │
│   │                                                  │
│   └─ ➕ Add Host    📁 Add Sub-Service              │
│                                                      │
│ ▶ ⚫ Another Service         0 hosts  ✏️ Start 🗑    │
│                                                      │
├─────────────────────────────────────────────────────┤
│ ✅ Authenticated as user@example.com                │
│ [🔑 Login] [➡️  Logout]          2 active connections│
└─────────────────────────────────────────────────────┘
```

### 2. Настройки (Settings Dialog)
```
┌───────────────────────────────────────────────────┐
│ Settings                                     [✖️]  │
├───────────────────────────────────────────────────┤
│                                                    │
│ ┌─ Datacenters ────────────────────────────────┐ │
│ │ Manage global list of datacenters            │ │
│ │                                               │ │
│ │ ┌───────────────────────────────────────────┐│ │
│ │ │ [hc]                              [✖️]     ││ │
│ │ │ [kc]                              [✖️]     ││ │
│ │ │ [pc]                              [✖️]     ││ │
│ │ └───────────────────────────────────────────┘│ │
│ │                                               │ │
│ │ [Add new...      ] [➕ Add]                   │ │
│ └───────────────────────────────────────────────┘ │
│                                                    │
│ ┌─ Port Forward Command ───────────────────────┐ │
│ │ [/usr/local/bin/mcc tp-port-forward        ]│ │
│ │ Example: /path/to/mcc db.com:5432 -p 5432  │ │
│ └───────────────────────────────────────────────┘ │
│                                                    │
│ ┌─ Authentication Commands ────────────────────┐ │
│ │ Login Command:                               │ │
│ │ [/usr/local/bin/mcc login                 ]│ │
│ │                                               │ │
│ │ Logout Command:                              │ │
│ │ [/usr/local/bin/mcc logout                ]│ │
│ └───────────────────────────────────────────────┘ │
│                                                    │
│ ┌─ Auto-Retry Connection ──────────────────────┐ │
│ │ [✓] Enable Auto-Retry                        │ │
│ │                                               │ │
│ │ Max Attempts:  [3]   Delay (sec): [5]        │ │
│ │                                               │ │
│ │ ℹ️  Will retry up to 3 times with 5s delay   │ │
│ └───────────────────────────────────────────────┘ │
│                                                    │
│ ┌─ Configuration Backup ───────────────────────┐ │
│ │ [📤 Export Configuration]                     │ │
│ │ [📥 Import Configuration]                     │ │
│ └───────────────────────────────────────────────┘ │
│                                                    │
├───────────────────────────────────────────────────┤
│ [📋 View Application Logs]                        │
│                                                    │
│ [Reset All to Defaults]    [Cancel]    [💾 Save] │
└───────────────────────────────────────────────────┘
```

### 3. Диалог добавления хоста (Add Host Dialog)
```
┌───────────────────────────────────────────────────┐
│ Add Host                                     [✖️]  │
├───────────────────────────────────────────────────┤
│                                                    │
│ Display Name:                                      │
│ [postgres-master                              ]   │
│                                                    │
│ Hostname Template:                                 │
│ [href.dfsdf.{location}.ru                    ]   │
│ Use {location} placeholder for datacenter          │
│                                                    │
│ Remote Port (on server):                           │
│ [5432  ]                                           │
│                                                    │
│ ────────────────────────────────────────────────   │
│                                                    │
│ ┌─ Select Datacenters ──────────── 3 selected ─┐ │
│ │                                               │ │
│ │ [✓] hc          →  [9999]                     │ │
│ │ [✓] kc          →  [10000]                    │ │
│ │ [✓] pc          →  [10001]                    │ │
│ │                                               │ │
│ │ Starting port: [9999] [Auto-assign]           │ │
│ └───────────────────────────────────────────────┘ │
│                                                    │
│                         [Cancel]  [➕ Add Host]   │
└───────────────────────────────────────────────────┘
```

## 📊 Модель данных

### Service (Сервис)
```kotlin
data class Service(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var hosts: MutableList<Host> = mutableListOf(),
    var childServices: MutableList<Service> = mutableListOf()
) {
    // Рекурсивный подсчет всех хостов
    val totalHostCount: Int get() = 
        hosts.size + childServices.sumOf { it.totalHostCount }
    
    // Получить все хосты рекурсивно
    val allHosts: List<Host> get() {
        val result = mutableListOf<Host>()
        result.addAll(hosts)
        childServices.forEach { result.addAll(it.allHosts) }
        return result
    }
}
```

### Host (Хост)
```kotlin
data class Host(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var hostnameTemplate: String,  // Может содержать {location}
    var remotePort: Int,            // Удаленный порт на сервере (например, 5432)
    var locations: MutableList<LocationMapping> = mutableListOf(),
    // Legacy поля для обратной совместимости (опционально)
    var hostname: String? = null,
    var tag: String? = null,
    var ports: MutableList<PortMapping>? = null
) {
    // Разрешить hostname для конкретного datacenter
    fun resolvedHostname(location: LocationMapping): String =
        hostnameTemplate.replace("{location}", location.datacenter)
    
    // Генерировать уникальный ID процесса для каждого location
    fun processId(location: LocationMapping): UUID =
        location.processId(id)
    
    // Совместимость: проверить, использует ли новую структуру
    val usesNewStructure: Boolean get() = locations.isNotEmpty()
    
    // Совместимость: получить порты (для отображения)
    val compatiblePorts: List<PortMapping> get() {
        if (!ports.isNullOrEmpty()) return ports!!
        return locations.map { PortMapping(fromPort = remotePort, toPort = it.localPort) }
    }
    
    // Совместимость: получить hostname
    val compatibleHostname: String get() = hostname ?: hostnameTemplate
    
    // Process ID для legacy port mapping
    fun processId(port: PortMapping): UUID {
        if (usesNewStructure) {
            locations.firstOrNull { it.localPort == port.toPort }?.let {
                return processId(it)
            }
        }
        return UUID.nameUUIDFromBytes("$id-${port.id}".toByteArray())
    }
}
```

### LocationMapping (Маппинг datacenter)
```kotlin
data class LocationMapping(
    val id: UUID = UUID.randomUUID(),
    var datacenter: String,  // Ссылка на глобальный datacenter (например, "hc", "kc")
    var localPort: Int       // Локальный порт на этой машине (например, 9999)
) {
    // Генерировать process ID для этого location
    fun processId(hostId: UUID): UUID =
        UUID.nameUUIDFromBytes("$hostId-$id".toByteArray())
}
```

### PortMapping (Маппинг портов)
```kotlin
data class PortMapping(
    val id: UUID = UUID.randomUUID(),
    var fromPort: Int,  // Remote port
    var toPort: Int     // Local port
) {
    val displayString: String get() = "$fromPort → $toPort"
}
```

### ProcessState (Состояние процесса)
```kotlin
enum class ProcessState(val displayName: String, val emoji: String) {
    STOPPED("Stopped", "⚫"),
    RUNNING("Running", "🟢"),
    ERROR("Error", "🔴"),
    PORT_IN_USE("Port Busy", "🟡"),
    RESTARTING("Restarting", "🟠")
}
```

## 🎯 Функциональность (детальное описание)

### 1. Управление сервисами

#### Добавление сервиса
- **UI**: Кнопка "➕" в header или кнопка "Add Sub-Service" в развернутом сервисе
- **Диалог**: Простой диалог с полем "Service Name"
- **Логика**: 
  - Создать новый Service с UUID
  - Добавить в корень или как child service
  - Сохранить в persistent storage

#### Редактирование сервиса
- **UI**: Кнопка "✏️" рядом с именем сервиса
- **Диалог**: Аналогичен добавлению, но с предзаполненным именем
- **Логика**: Обновить имя сервиса, сохранить изменения

#### Удаление сервиса
- **UI**: Кнопка "🗑" рядом с именем сервиса
- **Подтверждение**: Показать confirmation dialog
- **Логика**: 
  - Остановить все хосты рекурсивно (включая child services)
  - Удалить сервис из дерева
  - Очистить логи для всех хостов
  - Сохранить изменения

#### Start/Stop сервиса
- **UI**: Кнопка "Start" (зеленая) или "Stop" (красная)
- **Логика**:
  - Start: запустить все хосты и их порты рекурсивно
  - Stop: остановить все процессы рекурсивно
  - Обновить состояния в UI

### 2. Управление хостами

#### Добавление хоста (новая структура с datacenters)
- **UI**: Кнопка "➕ Add Host" в развернутом сервисе
- **Диалог**: (см. визуальную структуру выше)
  - **Display Name**: текстовое поле
  - **Hostname Template**: текстовое поле с placeholder "{location}"
  - **Remote Port**: числовое поле (только цифры)
  - **Select Datacenters**: 
    - Список всех доступных datacenters из настроек
    - Checkbox для каждого datacenter
    - При выборе datacenter появляется поле для local port
    - Кнопка "Auto-assign" автоматически назначает порты с шагом +1
    - Starting port: начальный порт для auto-assign (по умолчанию 9999)
- **Валидация**: 
  - Display Name не пустое
  - Hostname Template не пустой
  - Remote Port корректный (1-65535)
  - Выбран хотя бы один datacenter
  - Все local ports заполнены и уникальны
- **Логика**:
  - Создать Host с locations
  - Добавить к сервису
  - Сохранить в storage

#### Редактирование хоста
- **UI**: Кнопка "✏️" рядом с хостом
- **Диалог**: Аналогичен добавлению, предзаполнен данными
- **Логика**:
  - Остановить все процессы для этого хоста
  - Обновить данные хоста
  - Сохранить изменения

#### Удаление хоста
- **UI**: Кнопка "🗑" рядом с хостом
- **Подтверждение**: Показать confirmation dialog
- **Логика**:
  - Остановить все процессы
  - Удалить хост из сервиса
  - Очистить логи
  - Сохранить изменения

#### Start/Stop хоста
- **UI**: Кнопка с иконкой play/stop (▶/⏹)
- **Логика**:
  - Start: запустить процесс для каждого location/port
  - Stop: остановить все процессы хоста
  - Обновить UI состояния

### 3. Управление портами

#### Отображение портов
- **UI**: В развернутом хосте показать список портов
- **Формат**: `🟢 5432 → 9999  Running   📋 ❌ ▶`
  - Цветной индикатор состояния (🟢/⚫/🔴/🟡/🟠)
  - fromPort → toPort (monospace font, без пробелов в числах!)
  - Текстовое состояние (Running/Stopped/Error/Port Busy/Restarting)
  - Кнопка логов 📋
  - Кнопка kill process ❌ (только если процесс запущен)
  - Кнопка start/stop ▶/⏹

#### Start/Stop отдельного порта
- **UI**: Кнопка ▶/⏹ для конкретного порта
- **Логика**:
  - Start: запустить процесс для этого конкретного port mapping
  - Stop: остановить процесс
  - Обновить состояние

#### Kill Process (убить процесс на порту)
- **UI**: Кнопка ❌ (красная)
- **Подтверждение**: Модальное окно с текстом:
  ```
  Kill process on local port 9999?
  
  This will terminate any process using local port 9999
  
  [Cancel]  [Kill Process]
  ```
- **ВАЖНО**: Диалог должен оставаться открытым до явного выбора пользователя!
- **Логика**:
  - Выполнить `lsof -ti:PORT` для поиска PID
  - Выполнить `kill -9 PID` для завершения процесса
  - Установить состояние процесса в STOPPED
  - Показать уведомление об успехе/ошибке
  - **НЕ БЛОКИРОВАТЬ UI** - выполнять в фоновом потоке

#### Просмотр логов порта
- **UI**: Кнопка 📋
- **Логика**: Открыть диалог с логами для этого конкретного процесса

### 4. Процесс форвардинга портов

#### Запуск процесса
**Команда**:
```bash
{command} {resolved_hostname}:{remotePort} -p {localPort}
```
Пример:
```bash
/usr/local/bin/mcc tp-port-forward href.dfsdf.hc.ru:5432 -p 9999
```

**Состояния процесса**:
1. **STOPPED**: Процесс не запущен
2. **RUNNING**: Процесс запущен и работает нормально
3. **ERROR**: Ошибка при запуске или во время работы
4. **PORT_IN_USE**: Локальный порт уже занят
5. **RESTARTING**: Процесс перезапускается (при auto-retry)

**Определение состояния по логам**:
- **RUNNING**: если в логах есть строка содержащая "Proxying connections to"
- **PORT_IN_USE**: если в логах есть "Address already in use" или "port is already allocated"
- **ERROR**: если процесс завершился с ненулевым exit code или есть ошибки в stderr

**Логирование**:
- Захватывать stdout и stderr процесса
- Сохранять логи с timestamp для каждого process ID
- Показывать последние 1000 строк в log viewer
- Логи должны быть доступны в реальном времени

**Auto-Retry**:
- Если включен в настройках
- При ошибке или неожиданном завершении
- Попытки: из настроек (по умолчанию 3)
- Задержка между попытками: из настроек (по умолчанию 5 сек)
- Состояние меняется на RESTARTING во время retry

### 5. Аутентификация

#### Login
- **UI**: Кнопка "[🔑 Login]" в footer
- **Логика**:
  - Выполнить команду из настроек: `{loginCommand}`
  - Показать индикатор загрузки
  - Захватить вывод команды
  - Показать статус: "✅ Authenticated as user@example.com" или "❌ Login failed"
  - Обновить authStatus в UI

#### Logout
- **UI**: Кнопка "[➡️  Logout]" в footer
- **Логика**:
  - Выполнить команду из настроек: `{logoutCommand}`
  - Показать индикатор загрузки
  - Обновить authStatus
  - Очистить статус аутентификации

#### Отображение статуса
- **UI**: Текст над кнопками Login/Logout
- **Формат**: 
  - "✅ Authenticated as user@example.com" (зеленый)
  - "❌ Login failed: error message" (красный)
- **Цвет**: зеленый если начинается с "✅", красный если с "❌"

### 6. Настройки (Settings Dialog)

#### Datacenters
- **UI**: Список существующих datacenters с кнопками удаления
- **Добавление**: Текстовое поле + кнопка "Add"
- **Удаление**: Кнопка "✖️" рядом с каждым datacenter
- **Persistence**: Сохранять в PersistentStateComponent
- **Валидация**: datacenter name не пустой

#### Port Forward Command
- **UI**: Текстовое поле
- **Placeholder**: "/usr/local/bin/mcc tp-port-forward"
- **Пример**: Показать пример использования команды
- **Валидация**: не пустое

#### Authentication Commands
- **Login Command**: текстовое поле
- **Logout Command**: текстовое поле
- **Валидация**: оба не пустые

#### Auto-Retry Connection
- **Enable Auto-Retry**: checkbox
- **Max Attempts**: число (1-20)
- **Delay (seconds)**: число (1-60)
- **UI**: показать информационное сообщение о настройках

#### Configuration Backup (ВАЖНО!)
- **Export Configuration**: кнопка
  - Открыть File Chooser для выбора места сохранения .json файла
  - Сериализовать все services + settings (datacenters) в JSON
  - **БЕЗ UUID** в экспорте (только имена, hostname templates, порты)
  - Показать уведомление об успехе
  
- **Import Configuration**: кнопка
  - Открыть File Chooser для выбора .json файла
  - **ВАЖНО**: Остановить все запущенные сервисы перед импортом
  - Парсить JSON
  - Генерировать новые UUID для всех entities
  - Заменить существующие services
  - Заменить datacenters
  - Показать уведомление об успехе/ошибке
  - Перезагрузить UI

**Формат JSON для экспорта/импорта**:
```json
{
  "version": "1.0",
  "datacenters": ["hc", "kc", "pc"],
  "services": [
    {
      "name": "Production",
      "hosts": [
        {
          "name": "postgres-master",
          "hostnameTemplate": "href.dfsdf.{location}.ru",
          "remotePort": 5432,
          "locations": [
            {"datacenter": "hc", "localPort": 9999},
            {"datacenter": "kc", "localPort": 10000}
          ]
        }
      ],
      "childServices": [
        {
          "name": "Cache Layer",
          "hosts": [...],
          "childServices": []
        }
      ]
    }
  ]
}
```

#### View Application Logs
- **UI**: Кнопка "[📋 View Application Logs]"
- **Логика**: Открыть отдельное окно с логами приложения
- **Содержимое**: Системные логи (не логи процессов, а логи самого плагина)

#### Кнопки управления
- **Reset All to Defaults**: Сбросить все настройки к значениям по умолчанию
- **Cancel**: Закрыть без сохранения
- **Save**: Сохранить все изменения и закрыть

### 7. Логи

#### Log Viewer для процесса
- **Открытие**: Кнопка 📋 рядом с хостом или портом
- **UI**: Модальное окно
- **Заголовок**: имя хоста или "Host - Port 9999→5432"
- **Содержимое**: 
  - TextArea с монотонным шрифтом
  - Автоскролл вниз при новых логах
  - Возможность копирования текста
  - Кнопка "Clear Logs"
  - Кнопка "Close"
- **Форматирование**:
  - Строки с ошибками - красным
  - Timestamp в начале каждой строки
  - Максимум 1000 последних строк

#### Application Log Viewer
- **Открытие**: Из Settings → "View Application Logs"
- **UI**: Аналогично Log Viewer
- **Содержимое**: Логи самого плагина (действия пользователя, ошибки)

### 8. Active Connections Counter
- **UI**: В footer, справа: "2 active connections"
- **Логика**: Считать только RUNNING процессы портов (не агрегированные состояния)
- **Обновление**: В реальном времени при изменении состояний

### 9. Иерархия и развертывание

#### Expand/Collapse сервисов
- **UI**: Кнопка "▶" (свернуто) или "▼" (развернуто)
- **Анимация**: Плавное вращение иконки
- **Состояние**: Сохранять в памяти (не в persistence)

#### Expand/Collapse хостов
- **UI**: Кнопка "▶" или "▼"
- **Логика**: Показать/скрыть отдельные port mappings

#### Отступы для вложенности
- **Level 0** (root service): 0px отступ
- **Level 1** (child service): 16px отступ
- **Level 2** (child of child): 32px отступ
- И так далее...
- **Визуальный разделитель**: Вертикальная линия (2px, серая, прозрачность 0.2)

### 10. Persistence (сохранение данных)

#### Services и Hosts
- **Storage**: PersistentStateComponent
- **Format**: JSON serialization
- **Сохранение**: 
  - При добавлении/удалении/редактировании
  - Автоматически
- **Загрузка**: При инициализации плагина

#### Settings
- **Storage**: PersistentStateComponent (отдельный компонент)
- **Данные**:
  - Datacenters list
  - Commands (forward, login, logout)
  - Retry settings (enabled, attempts, delay)

#### Process States
- **НЕ сохранять** в persistence
- **Хранить в памяти**: Map<UUID, ProcessState>
- **Сброс**: При перезапуске IDE все процессы STOPPED

### 11. Контекстное меню (правый клик)

#### На сервисе
- Start Service
- Stop Service
- Edit Service
- Add Host
- Add Sub-Service
- Delete Service

#### На хосте
- Start Host
- Stop Host
- Edit Host
- View All Logs
- Delete Host

#### На порте
- Start Port
- Stop Port
- View Logs
- Kill Process

## 🎨 Визуальные детали (критично важно!)

### Цвета состояний
- **🟢 RUNNING**: Green (#28a745)
- **⚫ STOPPED**: Gray (#6c757d)
- **🔴 ERROR**: Red (#dc3545)
- **🟡 PORT_IN_USE**: Orange/Yellow (#ffc107)
- **🟠 RESTARTING**: Orange (#fd7e14)

### Шрифты
- **Основной**: System UI font
- **Монотонный** (для портов, команд): Monospace font
- **Размеры**:
  - Заголовок окна: 14pt, semibold
  - Имена сервисов: 14pt, semibold
  - Имена хостов: 12pt, medium
  - Hostname: 10pt, regular, secondary color
  - Порты: 11pt, monospace
  - Состояния: 10pt, regular
  - Кнопки: 11pt, regular

### Отступы и spacing
- **Padding в header/footer**: 16px horizontal, 12px vertical
- **Padding в service row**: 6px vertical
- **Padding в host row**: 4px vertical, 16px left
- **Padding в port row**: 3px vertical, 12px horizontal, 24px left
- **Spacing между элементами**: 8px (стандартно), 4px (компактно)

### Иконки (использовать Material Icons или аналоги)
- ⚙️ Settings: gear
- ➕ Add: plus circle
- ✖️ Close: x circle
- ✏️ Edit: pencil
- 🗑 Delete: trash
- ▶ Play: play circle fill
- ⏹ Stop: stop circle fill
- 📋 Logs: document text magnifying glass
- ❌ Kill: x circle fill (red)
- 🔑 Login: person badge key
- ➡️  Logout: arrow right square
- 📤 Export: arrow up tray
- 📥 Import: arrow down tray
- 📁 Folder: folder badge plus

### Размеры
- **Главное окно**: 500px width, 600px height (default)
- **Settings dialog**: 600px width, 650px height
- **Add/Edit Host dialog**: 450px width, 600px height
- **Log Viewer**: 700px width, 500px height

## ⚠️ Критичные требования

### 1. НЕ БЛОКИРОВАТЬ UI
- **ВСЕ** операции с процессами выполнять в фоновых потоках (Kotlin Coroutines)
- Показывать индикаторы загрузки
- UI должен оставаться отзывчивым

### 2. Форматирование чисел портов
- **НИКОГДА** не использовать locale-specific форматирование для портов
- **ВСЕГДА** отображать как строки: "9999", не "9 999"

### 3. Модальные окна Kill Process
- Диалог **НЕ ДОЛЖЕН** закрываться автоматически
- Должен оставаться открытым до явного выбора: "Kill" или "Cancel"

### 4. Импорт/экспорт БЕЗ UUID
- UUID генерируются автоматически при импорте
- В JSON файле - только понятные пользователю данные

### 5. Остановка перед импортом
- **ОБЯЗАТЕЛЬНО** останавливать все процессы перед импортом конфигурации

### 6. Real-time обновление UI
- Состояния процессов обновляются в реальном времени
- Логи обновляются в реальном времени
- Active connections counter обновляется в реальном времени

### 7. Правильная структура
- Все импорт/экспорт функции - в НАСТРОЙКАХ, не в главном окне

## 🏗️ Архитектура плагина

### Структура файлов
```
src/main/kotlin/com/mcc/portforwarder/
├── models/
│   ├── Service.kt
│   ├── Host.kt
│   ├── LocationMapping.kt
│   ├── PortMapping.kt
│   ├── ProcessState.kt
│   └── ConfigurationExport.kt
├── services/
│   ├── MCCPortForwarderService.kt  // Основная бизнес-логика
│   ├── MCCSettingsService.kt       // Настройки (PersistentStateComponent)
│   ├── ProcessExecutor.kt          // Запуск процессов
│   ├── LogService.kt               // Управление логами
│   └── PortKillerService.kt        // Убийство процессов на портах
├── toolwindow/
│   ├── MCCToolWindowFactory.kt     // Создание tool window
│   ├── MCCToolWindowContent.kt     // Основной UI
│   ├── SettingsDialog.kt           // Диалог настроек
│   ├── AddServiceDialog.kt         // Диалог добавления сервиса
│   ├── AddHostDialog.kt            // Диалог добавления хоста
│   ├── EditServiceDialog.kt        // Диалог редактирования сервиса
│   ├── EditHostDialog.kt           // Диалог редактирования хоста
│   ├── LogViewerDialog.kt          // Просмотр логов
│   └── AppLogViewerDialog.kt       // Просмотр логов приложения
└── utils/
    ├── UIHelper.kt                 // Утилиты для UI
    └── JsonHelper.kt               // Утилиты для JSON
```

### Главные компоненты

#### MCCToolWindowContent
- JPanel с BorderLayout
- **North**: Toolbar с кнопками (Settings, Add Service, Close)
- **Center**: JScrollPane с JTree для отображения иерархии
- **South**: Footer panel с Login/Logout и счетчиком connections
- **TreeModel**: Custom TreeModel для Service/Host/Port hierarchy

#### MCCPortForwarderService
- Singleton service
- Управляет всеми Process instances
- Хранит состояния процессов: `MutableMap<UUID, ProcessState>`
- Логи: `MutableMap<UUID, MutableList<LogEntry>>`
- Flow для обновления UI: `StateFlow<Map<UUID, ProcessState>>`

#### MCCSettingsService
- Implements `PersistentStateComponent`
- Хранит:
  - List<String> datacenters
  - String forwardCommand
  - String loginCommand
  - String logoutCommand
  - Boolean retryEnabled
  - Int retryAttempts
  - Int retryDelay

#### ProcessExecutor
- Запуск процессов через ProcessBuilder
- Захват stdout/stderr
- Мониторинг состояния процесса
- Auto-retry при ошибках

## 📝 Примеры кода (ключевые фрагменты)

### JTree для иерархии
```kotlin
class ServiceTreeModel(private val services: MutableList<Service>) : DefaultTreeModel(DefaultMutableTreeNode("Services")) {
    
    fun refresh() {
        (root as DefaultMutableTreeNode).removeAllChildren()
        services.forEach { service ->
            addServiceNode(root as DefaultMutableTreeNode, service)
        }
        reload()
    }
    
    private fun addServiceNode(parent: DefaultMutableTreeNode, service: Service) {
        val serviceNode = DefaultMutableTreeNode(TreeNodeData.ServiceNode(service))
        parent.add(serviceNode)
        
        service.hosts.forEach { host ->
            val hostNode = DefaultMutableTreeNode(TreeNodeData.HostNode(host))
            serviceNode.add(hostNode)
            
            host.compatiblePorts.forEach { port ->
                val portNode = DefaultMutableTreeNode(TreeNodeData.PortNode(host, port))
                hostNode.add(portNode)
            }
        }
        
        service.childServices.forEach { childService ->
            addServiceNode(serviceNode, childService)
        }
    }
}

sealed class TreeNodeData {
    data class ServiceNode(val service: Service) : TreeNodeData()
    data class HostNode(val host: Host) : TreeNodeData()
    data class PortNode(val host: Host, val port: PortMapping) : TreeNodeData()
}
```

### Custom Tree Cell Renderer
```kotlin
class MCCTreeCellRenderer : DefaultTreeCellRenderer() {
    override fun getTreeCellRendererComponent(
        tree: JTree, value: Any, selected: Boolean, expanded: Boolean, 
        leaf: Boolean, row: Int, hasFocus: Boolean
    ): Component {
        super.getTreeCellRendererComponent(tree, value, selected, expanded, leaf, row, hasFocus)
        
        val node = value as? DefaultMutableTreeNode
        val data = node?.userObject as? TreeNodeData
        
        when (data) {
            is TreeNodeData.ServiceNode -> {
                val state = getServiceState(data.service)
                text = "${state.emoji} ${data.service.name} (${data.service.totalHostCount} hosts)"
            }
            is TreeNodeData.HostNode -> {
                text = "${data.host.name} • ${data.host.compatibleHostname}"
                font = font.deriveFont(Font.PLAIN, 11f)
            }
            is TreeNodeData.PortNode -> {
                val state = getPortState(data.host, data.port)
                text = "${state.emoji} ${data.port.displayString} ${state.displayName}"
                font = Font("Monospaced", Font.PLAIN, 10)
            }
        }
        
        return this
    }
}
```

### Запуск процесса с логированием
```kotlin
suspend fun startPortForward(
    hostname: String, 
    remotePort: Int, 
    localPort: Int, 
    processId: UUID
) = withContext(Dispatchers.IO) {
    val command = settingsService.getForwardCommand()
    val fullCommand = "$command $hostname:$remotePort -p $localPort"
    
    val processBuilder = ProcessBuilder(command.split(" ") + listOf("$hostname:$remotePort", "-p", "$localPort"))
    processBuilder.redirectErrorStream(true)
    
    val process = processBuilder.start()
    processes[processId] = process
    
    // Update state
    updateState(processId, ProcessState.RUNNING)
    
    // Capture logs
    launch {
        process.inputStream.bufferedReader().useLines { lines ->
            lines.forEach { line ->
                logService.addLog(processId, line)
                // Check for specific patterns
                when {
                    line.contains("Proxying connections to") -> 
                        updateState(processId, ProcessState.RUNNING)
                    line.contains("Address already in use") -> 
                        updateState(processId, ProcessState.PORT_IN_USE)
                }
            }
        }
    }
    
    // Monitor process
    launch {
        val exitCode = process.waitFor()
        if (exitCode != 0 && settingsService.isRetryEnabled()) {
            retry(processId, hostname, remotePort, localPort)
        } else {
            updateState(processId, ProcessState.STOPPED)
        }
    }
}
```

## ✅ Чеклист реализации

### Phase 1: Базовая структура
- [ ] Создать все data class модели
- [ ] Настроить MCCSettingsService с persistence
- [ ] Реализовать MCCToolWindowFactory и базовый UI
- [ ] Добавить JTree с custom renderer

### Phase 2: Управление сервисами и хостами
- [ ] Диалог добавления сервиса
- [ ] Диалог редактирования сервиса
- [ ] Диалог удаления с подтверждением
- [ ] Диалог добавления хоста (с datacenters)
- [ ] Диалог редактирования хоста
- [ ] Auto-assign портов в диалоге хоста

### Phase 3: Процессы и логирование
- [ ] ProcessExecutor для запуска команд
- [ ] Захват stdout/stderr
- [ ] LogService для хранения логов
- [ ] LogViewerDialog для просмотра
- [ ] Real-time обновление логов

### Phase 4: Управление состояниями
- [ ] StateFlow для ProcessState
- [ ] Обновление UI в реальном времени
- [ ] Start/Stop для сервисов
- [ ] Start/Stop для хостов
- [ ] Start/Stop для портов

### Phase 5: Kill Process функциональность
- [ ] PortKillerService (lsof + kill)
- [ ] Confirmation dialog с правильным lifecycle
- [ ] Обновление состояния после kill
- [ ] Обработка ошибок

### Phase 6: Аутентификация
- [ ] Login command execution
- [ ] Logout command execution
- [ ] Auth status display
- [ ] UI индикаторы загрузки

### Phase 7: Настройки
- [ ] SettingsDialog UI
- [ ] Управление datacenters
- [ ] Настройка команд
- [ ] Auto-retry settings
- [ ] Save/Cancel/Reset

### Phase 8: Импорт/Экспорт
- [ ] Экспорт в JSON (без UUID)
- [ ] Импорт из JSON (генерация UUID)
- [ ] File chooser dialogs
- [ ] Остановка всех процессов перед импортом
- [ ] Валидация JSON

### Phase 9: Полировка UI
- [ ] Правильные цвета и иконки
- [ ] Правильные отступы
- [ ] Контекстное меню (правый клик)
- [ ] Active connections counter
- [ ] Expand/Collapse анимации
- [ ] Форматирование портов БЕЗ пробелов

### Phase 10: Тестирование
- [ ] Тест всех диалогов
- [ ] Тест запуска/остановки процессов
- [ ] Тест импорта/экспорта
- [ ] Тест kill process
- [ ] Тест auto-retry
- [ ] Тест persistence

## 🎯 Конечная цель

Создать плагин IntelliJ IDEA, который:
1. **Визуально идентичен** SwiftUI приложению (с учетом различий Swing vs SwiftUI)
2. **Функционально полон** - все возможности оригинального приложения
3. **Надежен** - не блокирует UI, корректно обрабатывает ошибки
4. **Удобен** - интуитивный интерфейс, понятные диалоги, реальное время обновления
5. **Импорт/экспорт в настройках** - БЕЗ UUID, с генерацией при импорте

---

**ВАЖНО**: Этот промпт содержит ПОЛНОЕ описание приложения. При реализации следуйте ему точно, особенно визуальным деталям, размещению импорт/экспорт в настройках, и требованиям к не блокирующему UI.

