#!/bin/bash
# Скрипт для автоматической локальной проверки проекта Antigravity Bar.
# Проверяет сборку, запускает юнит-тесты и проверяет код линтером SwiftLint (если установлен).

set -e

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_BAR_DIR="$PROJECT_DIR/status-bar"

echo -e "${YELLOW}=== Начало проверки проекта Antigravity Bar ===${NC}"

# 1. Сборка проекта
echo -e "\n${YELLOW}[1/3] Компиляция проекта (swift build)...${NC}"
if swift build --package-path "$STATUS_BAR_DIR"; then
    echo -e "${GREEN}✓ Сборка успешно завершена.${NC}"
else
    echo -e "${RED}✗ Ошибка компиляции проекта.${NC}"
    exit 1
fi

# 2. Запуск тестов
echo -e "\n${YELLOW}[2/3] Запуск модульных тестов (swift test)...${NC}"
if swift test --package-path "$STATUS_BAR_DIR"; then
    echo -e "${GREEN}✓ Все тесты успешно пройдены.${NC}"
else
    echo -e "${RED}✗ Ошибка выполнения тестов.${NC}"
    exit 1
fi

# 3. SwiftLint
echo -e "\n${YELLOW}[3/3] Проверка стилистики кода (SwiftLint)...${NC}"
if command -v swiftlint >/dev/null 2>&1; then
    # Запускаем swiftlint в директории status-bar
    if swiftlint lint "$STATUS_BAR_DIR"; then
        echo -e "${GREEN}✓ Проверка стилистики пройдена без ошибок.${NC}"
    else
        echo -e "${YELLOW}! Обнаружены предупреждения или ошибки форматирования SwiftLint.${NC}"
    fi
else
    echo -e "${YELLOW}! SwiftLint не установлен. Пропуск проверки стилистики.${NC}"
    echo -e "Для установки выполните: brew install swiftlint"
fi

echo -e "\n${GREEN}=== Проверка успешно завершена! ===${NC}"
