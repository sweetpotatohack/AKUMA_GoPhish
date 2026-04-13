#!/bin/bash

# Sneaky GoPhish Management Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Определяем docker compose v2 или docker-compose v1
if docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    echo "Ошибка: Docker Compose не найден. Установите его: https://docs.docker.com/compose/install/"
    exit 1
fi

show_help() {
    echo "Sneaky GoPhish Management Script"
    echo ""
    echo "Использование: $0 [команда]"
    echo ""
    echo "Доступные команды:"
    echo "  status      - Показать статус системы"
    echo "  password    - Получить пароль администратора"
    echo "  start       - Запустить GoPhish"
    echo "  stop        - Остановить GoPhish"
    echo "  restart     - Перезапустить GoPhish"
    echo "  logs        - Показать логи (follow)"
    echo "  renew-ssl   - Обновить SSL сертификаты"
    echo "  backup      - Создать бэкап базы данных"
    echo "  reset-admin - Сбросить пароль пользователя admin (нужен python3-bcrypt)"
    echo "  help        - Показать эту справку"
    echo ""
}

get_password() {
    echo "Получение пароля администратора..."
    password=$($COMPOSE logs sneaky_gophish 2>/dev/null \
        | grep -i "Please login with the username" \
        | tail -1 \
        | grep -o 'password [a-f0-9]*' \
        | cut -d' ' -f2)
    if [ -n "$password" ]; then
        echo ""
        echo "  Адрес  : https://$(grep -oP 'GOPHISH_ADMIN_URL=https?://\K[^:]+' "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || echo 'YOUR_DOMAIN'):3333"
        echo "  Логин  : admin"
        echo "  Пароль : $password"
        echo ""
    else
        echo "Пароль не найден в логах (это нормально, если база data/gophish.db уже существовала)."
        echo "GoPhish показывает случайный пароль только при первом создании БД."
        echo ""
        echo "  Варианты:"
        echo "    • Войти тем паролем, который вы задавали ранее."
        echo "    • Сбросить пароль:  $0 reset-admin 'НовыйНадёжныйПароль'"
        echo "    • Полная переустановка с новой БД: остановить контейнеры, удалить data/gophish.db, снова ./deploy_gophish.sh"
        echo "      (кампании и настройки будут потеряны; сначала сделайте backup.)"
    fi
}

# Сброс пароля admin в SQLite (bcrypt), пока контейнер остановлен
reset_admin_password() {
    local newpass="$1"
    if [ -z "$newpass" ]; then
        echo "Использование: $0 reset-admin 'НовыйПароль'"
        echo "Требуется пакет: apt-get install -y python3-bcrypt"
        exit 1
    fi

    local db="$SCRIPT_DIR/data/gophish.db"
    if [ ! -f "$db" ]; then
        echo "База не найдена: $db"
        exit 1
    fi

    if ! python3 -c "import bcrypt" 2>/dev/null; then
        echo "Установите: apt-get install -y python3-bcrypt"
        exit 1
    fi

    echo "Останавливаем контейнер GoPhish (освобождаем БД)..."
    $COMPOSE stop sneaky_gophish

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -a "$db" "$SCRIPT_DIR/backup_before_reset_${ts}.db"
    echo "Копия базы: $SCRIPT_DIR/backup_before_reset_${ts}.db"

    export GP_RESET_DB="$db"
    export GP_RESET_PASS="$newpass"
    if ! python3 << 'PY'
import bcrypt, sqlite3, os, sys
db_path = os.environ["GP_RESET_DB"]
password = os.environ["GP_RESET_PASS"]
h = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(10)).decode("ascii")
conn = sqlite3.connect(db_path)
cur = conn.execute("UPDATE users SET hash=? WHERE username=?", (h, "admin"))
conn.commit()
rc = cur.rowcount
conn.close()
sys.exit(2 if rc < 1 else 0)
PY
    then
        unset GP_RESET_DB GP_RESET_PASS
        echo "Ошибка: не удалось обновить пароль (проверьте python3-bcrypt и наличие пользователя admin)."
        $COMPOSE start sneaky_gophish
        exit 1
    fi
    unset GP_RESET_DB GP_RESET_PASS

    echo "Запускаем GoPhish..."
    $COMPOSE start sneaky_gophish
    echo ""
    echo "Пароль пользователя admin сброшен."
    echo "  Логин: admin"
    echo "  Пароль: (тот, что вы передали в reset-admin)"
}

show_status() {
    echo "Статус GoPhish:"
    $COMPOSE ps
    echo ""

    echo "Используемые порты:"
    ss -tlnp | grep -E ":3333|:443" || echo "  Порты не прослушиваются"
    echo ""

    get_password
}

start_gophish() {
    echo "Запуск GoPhish..."
    $COMPOSE up -d
    echo "GoPhish запущен!"
}

stop_gophish() {
    echo "Остановка GoPhish..."
    $COMPOSE down
    echo "GoPhish остановлен!"
}

restart_gophish() {
    echo "Перезапуск GoPhish..."
    $COMPOSE restart
    echo "GoPhish перезапущен!"
}

show_logs() {
    $COMPOSE logs -f sneaky_gophish
}

renew_ssl() {
    echo "Обновление SSL сертификатов..."
    if [ -f "$SCRIPT_DIR/renew_ssl.sh" ]; then
        bash "$SCRIPT_DIR/renew_ssl.sh"
    else
        echo "Файл renew_ssl.sh не найден. Запустите deploy_gophish.sh сначала."
        exit 1
    fi
}

backup_db() {
    echo "Создание бэкапа базы данных..."
    timestamp=$(date +%Y%m%d_%H%M%S)
    if docker exec sneaky_gophish_ssl test -f /opt/gophish/data/gophish.db 2>/dev/null; then
        docker cp sneaky_gophish_ssl:/opt/gophish/data/gophish.db "$SCRIPT_DIR/backup_${timestamp}.db"
    else
        docker cp sneaky_gophish_ssl:/opt/gophish/gophish.db "$SCRIPT_DIR/backup_${timestamp}.db" 2>/dev/null || \
            { echo "База данных не найдена в контейнере."; exit 1; }
    fi
    echo "Бэкап создан: $SCRIPT_DIR/backup_${timestamp}.db"
}

case "$1" in
    status)
        show_status
        ;;
    password)
        get_password
        ;;
    start)
        start_gophish
        ;;
    stop)
        stop_gophish
        ;;
    restart)
        restart_gophish
        ;;
    logs)
        show_logs
        ;;
    renew-ssl)
        renew_ssl
        ;;
    backup)
        backup_db
        ;;
    reset-admin)
        shift
        reset_admin_password "$*"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Неизвестная команда: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
