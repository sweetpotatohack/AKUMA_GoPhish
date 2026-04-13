#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    echo "Ошибка: Docker Compose не найден."
    exit 1
fi

echo "Информация о GoPhish"
echo ""

if $COMPOSE ps 2>/dev/null | grep -q "Up"; then
    echo "Статус: GoPhish работает"

    password=$($COMPOSE logs sneaky_gophish 2>/dev/null \
        | grep -i "Please login with the username" \
        | tail -1 \
        | grep -o 'password [a-f0-9]*' \
        | cut -d' ' -f2)

    if [ -n "$password" ]; then
        echo "Логин : admin"
        echo "Пароль: $password"
    else
        echo "Пароль в логах не найден (при существующей data/gophish.db GoPhish его не повторяет)."
        echo "Сброс: $SCRIPT_DIR/manage_gophish.sh reset-admin 'НовыйПароль'"
    fi
else
    echo "Статус: GoPhish не запущен"
    echo "Запустите: cd $SCRIPT_DIR && $COMPOSE up -d"
fi
