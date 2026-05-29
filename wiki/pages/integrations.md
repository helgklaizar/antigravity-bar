# Спецификация интеграций (Integrations)

Приложение **Antigravity Bar** активно интегрируется как с локальными компонентами среды разработки, так и с нативными API macOS, сторонними сервисами и IDE. В данном документе приведено детальное техническое описание всех видов интеграций.

---

## 1. Взаимодействие с локальным языковым сервером (Connect API)

Языковой сервер (daemon) является основным источником данных о квотах моделей. Статус-бар связывается с ним локально по HTTP-протоколу с использованием формата Connect JSON.

```
┌──────────────────┐               HTTP POST (Connect JSON)             ┌──────────────┐
│  AntigravityBar  │ ────────────────────────────────────────────────>  │  Language    │
│  (Status Bar)    │ <────────────────────────────────────────────────  │  Server      │
└──────────────────┘                 Response (Quota JSON)              └──────────────┘
```

### Спецификация API запроса
* **Метод:** `POST`
* **URL:** `http://127.0.0.1:<httpPort>/exa.language_server_pb.LanguageServerService/GetUserStatus`
* **Заголовки:**
  * `Connect-Protocol-Version: 1`
  * `X-Codeium-Csrf-Token: <csrfToken>` — токен сессии, извлеченный из аргументов процесса демона.
  * `Content-Type: application/json`
* **Тело запроса:**
  ```json
  {
    "metadata": {
      "ideName": "antigravity",
      "extensionName": "antigravity",
      "locale": "en"
    }
  }
  ```

### Обнаружение параметров демона (Daemon Discovery)
Обнаружение демонов происходит без статических конфигурационных файлов за счет динамического сканирования процессов ОС:
1. Вызывается системная функция Darwin `proc_listpids` для получения списка всех активных PIDs.
2. Для каждого PID с помощью `proc_pidpath` извлекается путь к исполняемому файлу. Отбираются процессы, содержащие в названии `language_server`.
3. С помощью вызова `sysctl` с MIB-массивом `[CTL_KERN, KERN_PROCARGS2, pid]` извлекается буфер аргументов командной строки. Из них парсятся параметры:
   * `--csrf_token <значение>`
   * `--extension_server_port <значение>`
4. С помощью системной утилиты `/usr/sbin/lsof -a -p <PID> -iTCP -sTCP:LISTEN -n -P` извлекаются сетевые порты, которые прослушивает данный демон.
5. Выполняется точечный POST-запрос проверки связи (ping) на обнаруженные порты для валидации доступности Connect API.

---

## 2. Telegram-мост и автоматизация IDE (AppleScript / CLI)

Telegram-мост позволяет удаленно передавать задачи разработчика в локальную среду IDE. Мост использует интеграцию с Telegram Bot API и средства автоматизации UI macOS.

```
┌──────────────┐          getUpdates          ┌────────────────┐         AppleScript         ┌──────────────────┐
│ Telegram Bot │ <──────────────────────────  │ AntigravityBar │ ──────────────────────────> │  Antigravity IDE │
│ API          │  ─────────────────────────>  │ (Telegram)     │                             │  (Active Window) │
└──────────────┘           Task message       └────────────────┘                             └──────────────────┘
```

### Схема прохождения команды:
1. Бот опрашивает Telegram Bot API через Long Polling:
   `https://api.telegram.org/bot<token>/getUpdates?offset=<last_id>`
2. Отфильтровываются сообщения по белому списку `ALLOWED_USER_ID`.
3. Сообщение парсится на команды:
   * `/task [текст]` — создание новой задачи.
   * `/open [проект]` — переключение проекта.
   * `/status` — отправка текущего состояния.
   * `/audit` — запуск экосистемного аудита.
4. При обработке `/task` статус-бар использует **AppleScript** для эмуляции нажатий клавиш и взаимодействия с интерфейсом IDE:

```swift
func injectTaskToIDE(_ task: String) {
    let script = """
    tell application "Antigravity"
        activate
        tell application "System Events"
            tell process "Antigravity"
                -- Cmd+N для открытия нового чата с ИИ
                keystroke "n" using command down
                delay 0.5
                -- Ввод текста задачи
                keystroke "\(task)"
                -- Отправка команды (нажатие Enter)
                key code 36
            end tell
        end tell
    end tell
    """
    var error: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&error)
}
```

5. Для запуска чатов в нужных папках статус-бар обращается напрямую к CLI-бинарнику среды разработки (пути извлекаются динамически: `/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide` или классический `/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity`):
   ```bash
   antigravity-ide chat
   ```

---

## 3. Нативные API macOS (Darwin & IOKit)

Статус-бар выполняет глубокий аппаратный мониторинг хоста, чтобы предупредить разработчика о перегрузках. Телеметрия считывается напрямую через C-интерфейсы macOS:

### CPU (Центральный процессор)
* **API:** `host_processor_info` с флагом `PROCESSOR_CPU_LOAD_INFO`.
* **Принцип:** Сравниваются такты процессора в режимах User, System, Nice и Idle между итерациями опроса. Вычисляется процент полезной утилизации.

### RAM (Оперативная память)
* **API:** `host_statistics64` с флагом `HOST_VM_INFO64` и функция `getpagesize()`.
* **Принцип:** Общий объем памяти определяется через `ProcessInfo.processInfo.physicalMemory`. Используемая память рассчитывается как:
  $$\text{Used Memory} = (\text{active\_count} + \text{wire\_count} + \text{compressor\_page\_count}) \times \text{pageSize}$$

### GPU (Графический ускоритель)
* **API:** `IOKit` (реестр ввода-вывода) для поиска сервисов с именем `IOAccelerator`.
* **Принцип:** Из свойств реестра считывается словарь `PerformanceStatistics` и извлекаются значения ключей `Device Utilization %` или `GPU Activity`.

### Автозапуск при входе (Launch at Login)
* **API:** Фреймворк `ServiceManagement` и класс `SMAppService.mainApp`.
* **Принцип:** Позволяет регистрировать статус-бар как фоновую службу в системе без необходимости запрашивать права суперпользователя.

---

## 4. Интеграция с Git и IDE (VS Code / Cursor)

Статус-бар предоставляет функцию «Гитхаб БД», которая помогает мгновенно находить и открывать локальные проекты:
1. В фоновом потоке запускается рекурсивный обход каталога `~/Projects`.
2. Исключаются папки зависимостей (`node_modules`, `Pods`, `build`, `dist`, `venv` и др.) с помощью метода `enumerator.skipDescendants()`.
3. Папки, содержащие подкаталог `.git`, идентифицируются как репозитории.
4. Создается локальный HTML-файл `github_db.html` во временной системной директории.
5. Ссылки на проекты формируются по протоколу глубоких ссылок (Deep Links) VS Code:
   `href="vscode://file/Users/username/Projects/my-project"`
6. Сгенерированный дашборд открывается в браузере по умолчанию через `NSWorkspace.shared.open()`. При клике на карточку проекта macOS автоматически запускает VS Code и открывает в нем выбранную рабочую область.
