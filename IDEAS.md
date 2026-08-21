# Ideas & Questions - Datacenter Management Feature

## 🎯 Цель
Упростить управление хостами в нескольких датацентрах:
- Один хост → несколько локаций (ДЦ)
- Глобальный список ДЦ в настройках
- Автоматическая подстановка {location} в hostname template

---

## 📋 Архитектура

### Модель данных:

```swift
// SettingsService
@Published var datacenters: [String] = ["dc1", "dc2", "eu-west"]

// Host
struct Host {
    var name: String                    // "postgres-master"
    var hostnameTemplate: String        // "href.dfsdf.{location}.ru"
    var remotePort: Int                 // 5432
    var locations: [LocationMapping]
}

struct LocationMapping {
    let id: UUID
    var datacenter: String              // "dc1"
    var localPort: Int                  // 9999
}
```

### Формирование команды:
```
Template: href.dfsdf.{location}.ru
DC: dc1
Remote: 5432
Local: 9999

→ Command: mcc tp-port-forward href.dfsdf.dc1.ru:5432 -p 9999
```

---

## ❓ Открытые вопросы

### 1. **Начальный порт по умолчанию**
- Какой порт предлагать первым при добавлении хоста?
- Варианты:
  - [ ] 9999 (фиксированный)
  - [ ] Найти первый свободный порт >= 9999
  - [ ] Запрашивать у пользователя стартовый порт

### 2. **Валидация портов**
- Проверять что порт не занят перед добавлением?
- Варианты:
  - [ ] Да, проверять через `lsof` и предупреждать
  - [ ] Нет, проверять только при запуске (как сейчас)
  - [ ] Опционально, с настройкой в Settings

### 3. **Удаление ДЦ из глобального списка**
- Что делать если ДЦ используется в хостах?
- Варианты:
  - [ ] Запретить удаление, показать где используется
  - [ ] Удалить и удалить из всех хостов (с предупреждением)
  - [ ] Удалить из списка, но оставить в хостах (legacy)

### 4. **Миграция существующих данных**
- Как обработать хосты со старой структурой (tag + multiple ports)?
- Варианты:
  - [ ] Автоматическая миграция при запуске
  - [ ] Ручная миграция (кнопка в Settings)
  - [ ] Поддержка обеих структур (legacy mode)

### 5. **Hostname template validation**
- Требовать обязательный placeholder `{location}`?
- Варианты:
  - [ ] Да, обязательно (иначе ошибка)
  - [ ] Нет, если нет - просто используется как есть
  - [ ] Предупреждение, но разрешить

### 6. **Порты при редактировании**
- Как изменять порты для существующих локаций?
- Варианты:
  - [ ] Можно менять свободно
  - [ ] Предупреждать если порт занят
  - [ ] Запретить изменение для запущенных процессов

### 7. **Bulk operations**
- Добавлять кнопки для групповых операций?
- Варианты:
  - [ ] "Start All Locations" - запустить все ДЦ хоста
  - [ ] "Stop All Locations" - остановить все ДЦ хоста
  - [ ] "Start All DC1" - запустить DC1 во всех хостах
  - [ ] Не нужно (запускаем по сервису)

### 8. **Порядок ДЦ в списке**
- Как сортировать датацентры?
- Варианты:
  - [ ] По алфавиту
  - [ ] По порядку добавления
  - [ ] Пользователь может перетаскивать (drag & drop)

### 9. **Default datacenters**
- Преднастроенные ДЦ при первом запуске?
- Варианты:
  - [ ] Пустой список (пользователь добавляет сам)
  - [ ] Предложить ["dc1", "dc2", "dc3"]
  - [ ] Показать wizard при первом запуске

### 10. **Auto-increment strategy**
- Как инкрементить порты при выборе нескольких ДЦ?
- Варианты:
  - [ ] Decrement: 9999, 9998, 9997... (текущее предложение)
  - [ ] Increment: 9999, 10000, 10001...
  - [ ] По выбору пользователя (настройка)

---

## 🚀 План реализации

### Phase 1: Core Models & Settings
- [ ] Добавить `datacenters: [String]` в SettingsService
- [ ] UI в Settings для управления ДЦ (CRUD)
- [ ] Создать новую модель `LocationMapping`
- [ ] Обновить модель `Host` с `hostnameTemplate`, `remotePort`, `locations`

### Phase 2: Add/Edit Host UI
- [ ] Форма Add Host с чекбоксами ДЦ
- [ ] Поля для портов с автоинкрементом
- [ ] Preview команд для каждого ДЦ
- [ ] Форма Edit Host с возможностью добавления/удаления локаций

### Phase 3: Display & Execution
- [ ] Expandable хост с вложенными локациями
- [ ] Отдельный статус для каждой локации
- [ ] Формирование команды с подстановкой {location}
- [ ] Логи для каждой локации отдельно

### Phase 4: Migration & Cleanup
- [ ] Миграция старых данных (если требуется)
- [ ] Удаление старых полей (tag, ports)
- [ ] Тесты и валидация

### Phase 5: Polish
- [ ] Валидация портов
- [ ] Error handling
- [ ] UI/UX improvements
- [ ] Documentation

---

## 💡 Дополнительные идеи

### Future enhancements:
1. **Import/Export ДЦ** - экспорт списка ДЦ в JSON/YAML
2. **Datacenter Groups** - группировка ДЦ (EU, US, ASIA)
3. **Connection Testing** - тест доступности хоста перед запуском
4. **Health Check** - периодическая проверка активных соединений
5. **Datacenter Status** - глобальный статус ДЦ (все хосты в DC1)
6. **Quick Switch** - быстрое переключение между ДЦ
7. **Port Ranges** - автоматическое выделение диапазона портов
8. **Templates** - шаблоны хостов для быстрого добавления

---

## 📝 Notes

### Current date: 2026-01-23
### Branch: feature/datacenter-tags
### Status: Planning & Design

---

## ✅ Decisions Made

1. Глобальный список ДЦ в Settings - APPROVED
2. Template с {location} placeholder - APPROVED
3. Один remote port на хост - APPROVED
4. Один local port на локацию - APPROVED
5. Чекбоксы для выбора ДЦ при добавлении - APPROVED

---

## 🔗 References

- Original discussion: См. чат
- Related files:
  - `MCCPortForwarder/MCCPortForwarder/Models/Service.swift`
  - `MCCPortForwarder/MCCPortForwarder/Services/SettingsService.swift`
  - `MCCPortForwarder/MCCPortForwarder/Views/ContentView.swift`
  - `MCCPortForwarder/MCCPortForwarder/Views/HostRowView.swift`

---

# Other ideas (parking lot, not scheduled)

## Presence / "who's using what" registry (2026-08-21)

Idea: a lightweight mechanism where every user's MCCPortForwarder instance connects to a shared
server and reports which hosts/ports/datacenters/instances it's currently forwarding. This would let
teammates see who else is already tunneled into a given service/DC before they duplicate work or
collide on shared resources.

Open questions to resolve before this becomes a real proposal:
- Where would the shared server live / who owns it (new service vs. piggyback on existing MCC infra)?
- Privacy: is "user X is connected to host Y" OK to broadcast to the whole team?
- Opt-in vs. always-on reporting.
- Conflict handling: what happens when two people target the same instance/port — just visibility, or active coordination?

Not to be implemented until explicitly prioritized.
