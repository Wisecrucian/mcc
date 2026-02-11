# Статус сборки MCC Port Forwarder Plugin

## Проблема

При создании плагина с нуля с правильными IntelliJ Platform компонентами возникло множество ошибок компиляции из-за:

### 1. Конфликт имен
- `com.mcc.portforwarder.models.Service` (модель данных)
- `com.intellij.openapi.components.Service` (аннотация)

**Решение**: Переименовал модель в `MCCServiceModel`

### 2. UI DSL Syntax
Старый синтаксис (не работает):
```kotlin
textField().bindText(::field)
scrollPane { textArea() }
```

Новый синтаксис (IntelliJ 2024.1+):
```kotlin
textField().text(field).also { cell -> ... }
cell { textArea() }
```

### 3. Множество мелких синтаксических ошибок
- ServiceExport → MCCServiceExport
- service.name → MCCServiceModel.name
- и т.д.

## Текущий статус

✅ **Архитектура правильная**:
- @Service с PersistentStateComponent
- DialogWrapper для диалогов
- AnAction для кнопок
- OSProcessHandler для процессов
- Правильная структура файлов

❌ **Compilation errors**: ~30 ошибок из-за рефакторинга Service → MCCServiceModel и UI DSL syntax

## Рекомендации

### Вариант 1: Продолжить исправление (долго)
Исправить все 30+ ошибок компиляции вручную. Займет еще ~1-2 часа работы.

### Вариант 2: Создать минимальную рабочую версию (быстро)
Создать упрощенную но **рабочую** версию плагина:
- ✅ Tool Window с пустым списком
- ✅ Базовая структура
- ✅ Компилируется и запускается
- ⏳ Функциональность добавляется пошагово

### Вариант 3: Использовать IntelliJ Platform Plugin Template
Начать с официального template проекта от JetBrains, который уже настроен правильно:
```bash
git clone https://github.com/JetBrains/intellij-platform-plugin-template
```

## Что уже сделано

✅ Правильная структура проекта
✅ Models (MCCServiceModel, Host, LocationMapping, ProcessState)
✅ Services с @Service аннотациями
✅ DialogWrapper диалоги
✅ AnAction для toolbar
✅ Tool Window Factory
✅ plugin.xml с правильной регистрацией
✅ Gradle build configuration

## Что нужно исправить

1. MCCService.kt - заменить все `service.field` на правильные типы (20+ мест)
2. UI DSL в всех диалогах - правильный синтаксис textField/textArea
3. MCCToolWindowPanel.kt - исправить типы в TreeNodeData
4. Все extension functions (.toExport(), .toService()) - правильные типы

## Файлы требующие исправления

```
dialogs/AddServiceDialog.kt        - 5 ошибок (UI DSL, types)
dialogs/AddHostDialog.kt            - 3 ошибки (UI DSL)
dialogs/LogViewerDialog.kt          - 3 ошибки (UI DSL)
dialogs/SettingsDialog.kt           - 3 ошибки (UI DSL)
services/MCCService.kt              - 15+ ошибок (service.field references)
toolwindow/MCCToolWindowPanel.kt    - 2 ошибки (types)
```

## Сколько времени осталось

- **Автоматическое исправление**: 30-60 минут
- **Ручное исправление**: 1-2 часа
- **Создание минимальной версии**: 20-30 минут

## Решение

Предлагаю создать **минимальную рабочую версию** сейчас, которая компилируется и запускается, а затем добавить функциональность пошагово. Это позволит вам протестировать плагин быстрее и убедиться что архитектура правильная.


