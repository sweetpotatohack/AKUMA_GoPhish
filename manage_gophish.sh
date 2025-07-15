#!/bin/bash

# 🔥 Феня's GoPhish Management Script 🔥

SCRIPT_DIR="/root/sneaky_gophish"
cd "$SCRIPT_DIR"

show_help() {
    echo "🔥 Феня's GoPhish Management Script 🔥"
    echo ""
    echo "Использование: ./manage_gophish.sh [команда]"
    echo ""
    echo "Доступные команды:"
    echo "  status      - Показать статус системы"
    echo "  password    - Получить пароль администратора"
    echo "  start       - Запустить GoPhish"
    echo "  stop        - Остановить GoPhish"
    echo "  restart     - Перезапустить GoPhish"
    echo "  logs        - Показать логи"
    echo "  renew-ssl   - Обновить SSL сертификаты"
    echo "  backup      - Создать бэкап базы данных"
    echo "  help        - Показать эту справку"
    echo ""
}

get_password() {
    echo "🔑 Получение пароля администратора..."
    password=$(docker-compose logs sneaky_gophish | grep password | tail -1 | grep -o 'password [a-f0-9]*' | cut -d' ' -f2 2>/dev/null)
    if [ -n "$password" ]; then
        echo "✅ Логин: admin"
        echo "✅ Пароль: $password"
        echo "🌐 Admin Panel: https://admin.trendcommunity.org:3333"
    else
        echo "❌ Не удалось получить пароль. Проверьте логи."
    fi
}

show_status() {
    echo "📊 Статус GoPhish:"
    docker-compose ps
    echo ""
    
    echo "🔌 Порты:"
    netstat -tlnp | grep -E ":3333|:443" 2>/dev/null || ss -tlnp | grep -E ":3333|:443"
    echo ""
    
    get_password
}

start_gophish() {
    echo "🚀 Запуск GoPhish..."
    docker-compose up -d
    echo "✅ GoPhish запущен!"
}

stop_gophish() {
    echo "🛑 Остановка GoPhish..."
    docker-compose down
    echo "✅ GoPhish остановлен!"
}

restart_gophish() {
    echo "🔄 Перезапуск GoPhish..."
    docker-compose restart
    echo "✅ GoPhish перезапущен!"
}

show_logs() {
    echo "📝 Логи GoPhish:"
    docker-compose logs -f sneaky_gophish
}

renew_ssl() {
    echo "🔒 Обновление SSL сертификатов..."
    certbot renew --quiet
    cp /etc/letsencrypt/live/admin.trendcommunity.org/fullchain.pem ./ssl/admin.crt
    cp /etc/letsencrypt/live/admin.trendcommunity.org/privkey.pem ./ssl/admin.key
    cp /etc/letsencrypt/live/admin.trendcommunity.org/fullchain.pem ./ssl/phish.crt
    cp /etc/letsencrypt/live/admin.trendcommunity.org/privkey.pem ./ssl/phish.key
    chmod 644 ./ssl/*
    docker-compose restart
    echo "✅ SSL сертификаты обновлены!"
}

backup_db() {
    echo "💾 Создание бэкапа базы данных..."
    timestamp=$(date +%Y%m%d_%H%M%S)
    docker exec sneaky_gophish_ssl cp /opt/gophish/gophish.db /opt/gophish/backup_${timestamp}.db
    docker cp sneaky_gophish_ssl:/opt/gophish/backup_${timestamp}.db ./backup_${timestamp}.db
    echo "✅ Бэкап создан: backup_${timestamp}.db"
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
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Неизвестная команда: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
