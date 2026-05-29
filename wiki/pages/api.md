# Спецификация API и сетевых протоколов

Поскольку Antigravity Bar является клиентским приложением, оно не предоставляет собственные сетевые службы вовне. Однако оно активно взаимодействует с локальными экземплярами демона **Antigravity Language Server** по протоколам HTTP/Connect-Protobuf и осуществляет интеграцию через файлы конфигурации на диске.

---

## 1. Взаимодействие с языковым сервером (HTTP / Connect Protocol)

Связь с демоном осуществляется по протоколу Connect (упрощенная версия gRPC над HTTP/1.1 с использованием JSON).

### Эндпоинт получения квот пользователя
- **Метод:** `POST`
- **Путь:** `http://127.0.0.1:<httpPort>/exa.language_server_pb.LanguageServerService/GetUserStatus`
- **Таймаут:** 5 секунд (2 секунды при пинге доступности порта).

### Обязательные заголовки запроса
| Заголовок | Значение | Описание |
| :--- | :--- | :--- |
| `Connect-Protocol-Version` | `1` | Версия протокола Connect |
| `X-Codeium-Csrf-Token` | `<csrfToken>` | Токен авторизации, уникальный для текущей сессии демона |
| `Content-Type` | `application/json` | Формат передаваемых данных |

### Тело запроса (JSON)
```json
{
  "metadata": {
    "ideName": "antigravity",
    "extensionName": "antigravity",
    "locale": "en"
  }
}
```

### Структура ответа (JSON)
Демон возвращает статус пользователя, включая квоты моделей. Пример ответа:
```json
{
  "userStatus": {
    "email": "user@example.com",
    "name": "Developer Name",
    "cascadeModelConfigData": {
      "clientModelConfigs": [
        {
          "label": "Flash",
          "quotaInfo": {
            "remainingFraction": 0.85,
            "resetTime": "2026-05-25T12:00:00Z"
          }
        },
        {
          "label": "Pro",
          "quotaInfo": {
            "remainingFraction": 0.0,
            "resetTime": "2026-05-25T04:30:00Z"
          }
        }
      ]
    }
  }
}
```

### Обработка квот в приложении
- **`remainingFraction`**: Значение от `0.0` до `1.0`. Приложение преобразует его в проценты (0–100%) для отображения индикатора-пирога.
- **`resetTime`**: Время сброса квоты в формате ISO 8601. Приложение рассчитывает разницу с текущим временем системы и показывает таймер обратного отсчета (например, `4h 30m` или `Ready`).

---

## 2. Формат файлов обнаружения (Daemon Discovery JSON)

В некоторых случаях (или при резервных сценариях) демон записывает информацию о своей сессии в директорию `~/.gemini/antigravity/daemon/` в виде JSON-файлов. Приложение может сканировать эту папку для получения параметров подключения.

### Структура файла конфигурации демона
Каждый файл содержит следующие поля:

| Поле | Тип | Описание |
| :--- | :--- | :--- |
| `pid` | `Int` | Идентификатор процесса демона |
| `httpPort` | `Int` | Порт для взаимодействия по HTTP Connect API |
| `httpsPort` | `Int` | Порт для HTTPS соединений (в текущей версии не используется, равен `0`) |
| `csrfToken` | `String` | Уникальный токен безопасности сессии |
| `path` | `String` | Абсолютный путь к исполняемому файлу демона |

Пример файла:
```json
{
  "pid": 58204,
  "httpPort": 58621,
  "httpsPort": 0,
  "csrfToken": "a1b2c3d4e5f6...",
  "path": "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/language_server_macos"
}
```

---

## 3. Файловый формат реестра (Registry JSON)

Файл `registry.json` располагается в корневом рабочем каталоге `~/.gemini/antigravity/` и определяет источники для встроенного менеджера пакетов ИИ-навыков.

### Структура реестра
Реестр представляет собой JSON-массив секций с репозиториями:
```json
[
  {
    "title": "🌌 Core Antigravity",
    "isEnabled": true,
    "repositories": [
      "https://github.com/sickn33/antigravity-awesome-skills"
    ]
  },
  {
    "title": "⚡ Frontend Community",
    "isEnabled": false,
    "repositories": [
      "https://github.com/midudev/autoskills"
    ]
  }
]
```

### Логика работы менеджера пакетов:
1. Приложение считывает `registry.json` при инициализации.
2. При запуске анализатора (`Analyze System`) опрашиваются только те репозитории, в секциях которых флаг `isEnabled` равен `true`.
3. Обновление источников и добавление новых адресов репозиториев перезаписывает данный файл на диске.
