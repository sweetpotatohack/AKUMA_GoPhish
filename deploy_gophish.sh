#!/bin/bash

# 🔥 Феня's Sneaky GoPhish Deployment Script 🔥

set -e

# Конфигурация
GITHUB_REPO="https://github.com/puzzlepeaches/sneaky_gophish"
EMAIL="dmitriyvisotskiydr15061991@gmail.com"
DOMAIN_ADMIN="admin.trendcommunity.org"
DOMAIN_PHISH="trendcommunity.org"
INSTALL_DIR="/root/sneaky_gophish"

# Цветной вывод
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен запускаться от root!"
        exit 1
    fi
}

# Установка зависимостей
install_dependencies() {
    print_status "Установка зависимостей..."
    apt-get update -qq
    apt-get install -y certbot git docker.io docker-compose-plugin curl
    systemctl start docker
    systemctl enable docker
    print_status "Зависимости установлены"
}

# Клонирование и сборка
clone_and_build() {
    print_status "Клонирование репозитория..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    git clone "$GITHUB_REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    print_status "Сборка Docker контейнера..."
    docker build -t sneaky_gophish .
    print_status "Контейнер собран"
}

# Создание SSL директории
create_ssl_directory() {
    mkdir -p "$INSTALL_DIR/ssl"
    chmod 755 "$INSTALL_DIR/ssl"
}

# Генерация SSL сертификатов
generate_ssl() {
    print_status "Остановка возможных сервисов на портах 80/443..."
    docker stop $(docker ps -q) 2>/dev/null || true
    
    print_status "Генерация SSL сертификатов для $DOMAIN_ADMIN и $DOMAIN_PHISH..."
    certbot certonly --standalone \
        -d "$DOMAIN_ADMIN" \
        -d "$DOMAIN_PHISH" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive
    
    print_status "Копирование сертификатов..."
    cp "/etc/letsencrypt/live/$DOMAIN_ADMIN/fullchain.pem" "$INSTALL_DIR/ssl/admin.crt"
    cp "/etc/letsencrypt/live/$DOMAIN_ADMIN/privkey.pem" "$INSTALL_DIR/ssl/admin.key"
    cp "/etc/letsencrypt/live/$DOMAIN_ADMIN/fullchain.pem" "$INSTALL_DIR/ssl/phish.crt"
    cp "/etc/letsencrypt/live/$DOMAIN_ADMIN/privkey.pem" "$INSTALL_DIR/ssl/phish.key"
    
    # Исправляем права доступа
    chmod 644 "$INSTALL_DIR/ssl"/*
    print_status "SSL сертификаты готовы"
}

# Создание конфигурации
create_config() {
    print_status "Создание конфигурации GoPhish..."
    cat > "$INSTALL_DIR/config.json" << CONFIG_EOF
{
  "admin_server": {
    "listen_url": "0.0.0.0:3333",
    "use_tls": true,
    "cert_path": "/opt/gophish/ssl/admin.crt",
    "key_path": "/opt/gophish/ssl/admin.key"
  },
  "phish_server": {
    "listen_url": "0.0.0.0:443",
    "use_tls": true,
    "cert_path": "/opt/gophish/ssl/phish.crt",
    "key_path": "/opt/gophish/ssl/phish.key"
  },
  "db_name": "sqlite3",
  "db_path": "gophish.db",
  "migrations_prefix": "db/db_",
  "contact_address": "$EMAIL",
  "logging": {
    "filename": "gophish.log",
    "level": "info"
  }
}
CONFIG_EOF
    print_status "Конфигурация создана"
}

# Создание docker-compose файла
create_docker_compose() {
    print_status "Создание docker-compose.yml..."
    cat > "$INSTALL_DIR/docker-compose.yml" << COMPOSE_EOF
version: '3.8'

services:
  sneaky_gophish:
    image: sneaky_gophish:latest
    container_name: sneaky_gophish_ssl
    ports:
      - "3333:3333"  # Admin panel HTTPS
      - "443:443"    # Phish server HTTPS
    volumes:
      - ./ssl:/opt/gophish/ssl
      - ./config.json:/opt/gophish/config.json
    restart: unless-stopped
    environment:
      - GOPHISH_ADMIN_URL=https://$DOMAIN_ADMIN:3333
      - GOPHISH_PHISH_URL=https://$DOMAIN_PHISH

volumes:
  gophish_data:
COMPOSE_EOF
    print_status "Docker Compose конфигурация создана"
}

# Запуск контейнера
run_container() {
    print_status "Запуск GoPhish контейнера..."
    cd "$INSTALL_DIR"
    docker-compose up -d
    
    # Ждем запуска
    sleep 5
    
    print_status "Получение пароля администратора..."
    password=$(docker-compose logs sneaky_gophish | grep password | tail -1 | grep -o 'password [a-f0-9]*' | cut -d' ' -f2)
    
    if [ -n "$password" ]; then
        print_status "Пароль администратора: $password"
    else
        print_warning "Не удалось получить пароль. Проверьте логи: docker-compose logs sneaky_gophish"
    fi
}

# Создание скрипта обновления сертификатов
create_renewal_script() {
    print_status "Создание скрипта обновления сертификатов..."
    cat > "$INSTALL_DIR/renew_ssl.sh" << RENEW_EOF
#!/bin/bash
# Скрипт обновления SSL сертификатов
certbot renew --quiet
cp /etc/letsencrypt/live/$DOMAIN_ADMIN/fullchain.pem $INSTALL_DIR/ssl/admin.crt
cp /etc/letsencrypt/live/$DOMAIN_ADMIN/privkey.pem $INSTALL_DIR/ssl/admin.key
cp /etc/letsencrypt/live/$DOMAIN_ADMIN/fullchain.pem $INSTALL_DIR/ssl/phish.crt
cp /etc/letsencrypt/live/$DOMAIN_ADMIN/privkey.pem $INSTALL_DIR/ssl/phish.key
chmod 644 $INSTALL_DIR/ssl/*
cd $INSTALL_DIR && docker-compose restart
RENEW_EOF
    chmod +x "$INSTALL_DIR/renew_ssl.sh"
    
    # Добавляем в cron
    (crontab -l 2>/dev/null; echo "0 3 * * * $INSTALL_DIR/renew_ssl.sh") | crontab -
    print_status "Автообновление SSL настроено"
}

# Показать итоги
show_summary() {
    print_status "🔥 Развертывание завершено! 🔥"
    echo ""
    echo "Admin Panel: https://$DOMAIN_ADMIN:3333"
    echo "Phish Server: https://$DOMAIN_PHISH"
    echo "Username: admin"
    echo "Password: $(docker-compose logs sneaky_gophish | grep password | tail -1 | grep -o 'password [a-f0-9]*' | cut -d' ' -f2 2>/dev/null || echo 'Проверьте логи')"
    echo ""
    echo "Команды управления:"
    echo "  Статус: docker-compose ps"
    echo "  Логи: docker-compose logs -f sneaky_gophish"
    echo "  Перезапуск: docker-compose restart"
    echo "  Остановка: docker-compose down"
    echo ""
    echo "SSL сертификаты будут автоматически обновляться!"
}

# Основная функция
main() {
    echo "🔥 Феня's Sneaky GoPhish Deployment Script 🔥"
    echo ""
    
    check_root
    install_dependencies
    clone_and_build
    create_ssl_directory
    generate_ssl
    create_config
    create_docker_compose
    run_container
    create_renewal_script
    show_summary
}

# Запуск
main "$@"
