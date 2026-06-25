#!/bin/bash

# Sneaky GoPhish Deployment Script

set -e

# Директория скрипта — используется как INSTALL_DIR
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Конфигурация — измените под свой домен и email
EMAIL="dm1111@gmail.com"
DOMAIN_ADMIN="admin.max.news"
DOMAIN_PHISH="helpdesk.max.news"

# Цветной вывод
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status()  { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error()   { echo -e "${RED}[-]${NC} $1"; }

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен запускаться от root!"
        exit 1
    fi
}

# Определяем команду docker compose (v2 плагин) или docker-compose (v1)
detect_compose() {
    if docker compose version &>/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif command -v docker-compose &>/dev/null 2>&1; then
        COMPOSE="docker-compose"
        print_warning "Используется docker-compose v1. Рекомендуется обновить до Docker Compose v2."
    else
        print_error "Docker Compose не найден!"
        exit 1
    fi
    print_status "Docker Compose команда: $COMPOSE"
}

# Установка зависимостей
install_dependencies() {
    print_status "Установка базовых зависимостей..."
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release certbot git openssl python3-bcrypt

    # Проверяем наличие docker compose v2 (плагин)
    if ! docker compose version &>/dev/null 2>&1; then
        print_status "Устанавливаем Docker Compose plugin из официального репозитория Docker..."

        # Добавляем официальный Docker GPG ключ и репозиторий
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
$(lsb_release -cs) stable" \
            | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -qq
        # Устанавливаем compose-plugin (+ docker-ce если ещё нет)
        apt-get install -y docker-compose-plugin docker-buildx-plugin
    fi

    # Убеждаемся что Docker запущен
    if ! command -v docker &>/dev/null; then
        apt-get install -y docker-ce docker-ce-cli containerd.io
    fi
    systemctl start docker
    systemctl enable docker

    detect_compose
    print_status "Зависимости установлены"
}

# Создание необходимых директорий
create_directories() {
    print_status "Создание директорий..."
    mkdir -p "$INSTALL_DIR/ssl"
    mkdir -p "$INSTALL_DIR/data"
    mkdir -p "$INSTALL_DIR/uploads"
    chmod 755 "$INSTALL_DIR/ssl"
    chmod 755 "$INSTALL_DIR/data"
    chmod 777 "$INSTALL_DIR/uploads"
    # GoPhish запускается как uid 1000 (user app) — даём ему права на data/
    chown -R 1000:1000 "$INSTALL_DIR/data"
}

# Сборка Docker образа
build_image() {
    print_status "Сборка Docker образа sneaky_gophish..."
    cd "$INSTALL_DIR"
    docker build -t sneaky_gophish .
    print_status "Образ собран"
}

# Certbot при втором выпуске кладёт файлы в admin.domain-0001, а не в admin.domain — нельзя копировать из старого пути.
pick_newest_le_live_dir() {
    local best="" best_t=0 d t
    for d in "/etc/letsencrypt/live/$DOMAIN_ADMIN" /etc/letsencrypt/live/${DOMAIN_ADMIN}-*; do
        [ -f "$d/fullchain.pem" ] || continue
        t=$(stat -c %Y "$d/fullchain.pem" 2>/dev/null || echo 0)
        if [ "${t:-0}" -gt "${best_t:-0}" ]; then best_t=$t; best=$d; fi
    done
    if [ -n "$best" ]; then
        echo "$best"
        return 0
    fi
    echo "/etc/letsencrypt/live/$DOMAIN_ADMIN"
}

# Копирование LE в ssl/; опционально certbot.log — взять путь из строки "Certificate is saved at:"
copy_le_certs_to_ssl_dir() {
    local le_dir="" certbot_log="${1:-}"
    if [ -n "$certbot_log" ] && [ -f "$certbot_log" ]; then
        le_dir=$(grep 'Certificate is saved at:' "$certbot_log" 2>/dev/null | head -1 | sed 's/.*Certificate is saved at:[[:space:]]*//' | tr -d '\r')
        le_dir=$(dirname "$le_dir")
    fi
    if [ -z "$le_dir" ] || [ ! -f "$le_dir/fullchain.pem" ]; then
        le_dir=$(pick_newest_le_live_dir)
    fi
    print_status "Копируем Let's Encrypt в ssl/ из каталога: $le_dir"
    cp "$le_dir/fullchain.pem" "$INSTALL_DIR/ssl/admin.crt"
    cp "$le_dir/privkey.pem"   "$INSTALL_DIR/ssl/admin.key"
    cp "$le_dir/fullchain.pem" "$INSTALL_DIR/ssl/phish.crt"
    cp "$le_dir/privkey.pem"   "$INSTALL_DIR/ssl/phish.key"
    chmod 644 "$INSTALL_DIR/ssl"/*
}

# Удалить старые LE-цепочки для этого проекта (admin.domain, admin.domain-0001, …) и копии в ssl/
purge_old_certificates() {
    print_status "Очищаем старые сертификаты, затем выпустим новые (только имена $DOMAIN_ADMIN / ${DOMAIN_ADMIN}-*)..."
    rm -f "$INSTALL_DIR/ssl"/*.crt "$INSTALL_DIR/ssl"/*.key 2>/dev/null || true

    if ! command -v certbot >/dev/null 2>&1; then
        return 0
    fi
    local name
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if [[ "$name" == "$DOMAIN_ADMIN" || "$name" == "$DOMAIN_ADMIN"-* ]]; then
            print_status "  Удаляем цепочку Let's Encrypt: $name"
            certbot delete --cert-name "$name" --non-interactive 2>/dev/null || true
        fi
    done < <(certbot certificates 2>/dev/null | sed -n 's/^[[:space:]]*Certificate Name:[[:space:]]*//p')

    print_status "Локальные ssl/*.crt, ssl/*.key и цепочки LE (через certbot delete) для $DOMAIN_ADMIN очищены."
    print_warning "Учтите лимиты Let's Encrypt (~5 выпусков на те же имена за 7 дней при частых перезапусках)."
}

# Остановить весь стек и старые контейнеры — certbot --standalone должен слушать :80 один
free_stack_for_certbot() {
    print_status "Останавливаем Docker-стек, чтобы освободить порт 80 для Let's Encrypt..."
    cd "$INSTALL_DIR"
    if [ -f docker-compose.yml ] && [ -n "${COMPOSE:-}" ]; then
        $COMPOSE down --remove-orphans 2>/dev/null || true
    fi
    docker stop sneaky_gophish_ssl sneaky_gophish_nginx sneaky_gophish_upload 2>/dev/null || true
    sleep 2
}

# Предупреждение: LE может ходить по IPv6, если есть AAAA
warn_if_aaaa_points_elsewhere() {
    local aaaa
    aaaa=$(dig +short AAAA "$DOMAIN_ADMIN" 2>/dev/null | head -1)
    if [ -n "$aaaa" ]; then
        print_warning "У $DOMAIN_ADMIN есть AAAA: $aaaa — проверка Let's Encrypt может идти по IPv6."
        print_warning "Если IPv6 не настроен на этом сервере, временно удалите AAAA или настройте v6 на этот же хост."
    fi
}

# Показать, кто занял порт 80 (если занят)
show_port_80_users() {
    if ss -tlnp 2>/dev/null | grep -qE ':80(\s|$)'; then
        print_warning "Порт 80 всё ещё занят — certbot (standalone) не сможет запуститься:"
        ss -tlnp | grep -E ':80(\s|$)' || true
        return 1
    fi
    return 0
}

# Генерация Let's Encrypt SSL (с fallback на self-signed)
generate_ssl() {
    print_warning "Требования для Let's Encrypt (HTTP-01, standalone):"
    print_warning "  1. DNS A: $DOMAIN_ADMIN и $DOMAIN_PHISH → публичный IP этого сервера"
    print_warning "  2. Порт 80 TCP свободен локально и открыт с интернета (фаервол)"
    print_warning "  3. Нет конфликтующей AAAA на чужой хост (см. предупреждение ниже)"

    warn_if_aaaa_points_elsewhere

    free_stack_for_certbot
    purge_old_certificates

    if ! show_port_80_users; then
        print_error "Освободите порт 80 (остановите apache/nginx/другой процесс) и запустите скрипт снова."
    fi

    local certbot_tmp
    certbot_tmp=$(mktemp)
    print_status "Запрос нового сертификата Let's Encrypt (certonly --standalone)..."

    set +e
    certbot certonly \
        --standalone \
        --preferred-challenges http \
        --http-01-port 80 \
        -d "$DOMAIN_ADMIN" \
        -d "$DOMAIN_PHISH" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive \
        2>&1 | tee "$certbot_tmp"
    local certbot_exit=${PIPESTATUS[0]}
    set -e

    if [ "$certbot_exit" -eq 0 ]; then
        print_status "Let's Encrypt: сертификат получен."
        copy_le_certs_to_ssl_dir "$certbot_tmp"
        SSL_TYPE="letsencrypt"
        rm -f "$certbot_tmp"
        return 0
    fi

    print_warning "Let's Encrypt завершился с кодом $certbot_exit. Последний вывод certbot:"
    cat "$certbot_tmp"
    rm -f "$certbot_tmp"
    if [ -f "/var/log/letsencrypt/letsencrypt.log" ]; then
        print_warning "Хвост /var/log/letsencrypt/letsencrypt.log:"
        tail -n 25 /var/log/letsencrypt/letsencrypt.log 2>/dev/null || true
    fi
    print_warning "Проверьте: ufw allow 80/tcp / iptables, облачный security group (ingress 80), порт 80 не занят."
    print_warning "Генерируем self-signed (браузер покажет предупреждение)..."
    generate_self_signed
    SSL_TYPE="selfsigned"
}

# Генерация self-signed сертификата как fallback
generate_self_signed() {
    print_status "Генерация self-signed сертификата..."
    openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
        -keyout "$INSTALL_DIR/ssl/admin.key" \
        -out    "$INSTALL_DIR/ssl/admin.crt" \
        -subj "/C=US/ST=State/L=City/O=Org/CN=$DOMAIN_ADMIN" \
        -addext "subjectAltName=DNS:$DOMAIN_ADMIN,DNS:$DOMAIN_PHISH" 2>/dev/null

    cp "$INSTALL_DIR/ssl/admin.crt" "$INSTALL_DIR/ssl/phish.crt"
    cp "$INSTALL_DIR/ssl/admin.key" "$INSTALL_DIR/ssl/phish.key"
    chmod 644 "$INSTALL_DIR/ssl"/*
    print_status "Self-signed сертификат создан (действителен 365 дней)"
}

# Создание config.json — фишинг: TLS на :443 в самом GoPhish (без nginx)
create_config() {
    print_status "Создание config.json..."
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
  "db_path": "data/gophish.db",
  "migrations_prefix": "db/db_",
  "contact_address": "$EMAIL",
  "logging": {
    "filename": "",
    "level": "info"
  }
}
CONFIG_EOF
    print_status "config.json создан"
}

# Создание docker-compose.yml
create_docker_compose() {
    print_status "Создание docker-compose.yml..."
    cat > "$INSTALL_DIR/docker-compose.yml" << COMPOSE_EOF
services:

  # GoPhish: admin TLS :3333, phish TLS :443; /upload → Flask (прокси в phish.go)
  sneaky_gophish:
    build: .
    image: sneaky_gophish:latest
    container_name: sneaky_gophish_ssl
    ports:
      - "3333:3333"
      - "443:443"
    volumes:
      - ./ssl:/opt/gophish/ssl
      - ./config.json:/opt/gophish/config.json
      - ./data:/opt/gophish/data
    restart: unless-stopped
    depends_on:
      - upload_server
    environment:
      - GOPHISH_ADMIN_URL=https://$DOMAIN_ADMIN:3333
      - GOPHISH_PHISH_URL=https://$DOMAIN_PHISH

  upload_server:
    build:
      context: .
      dockerfile: Dockerfile.upload
    image: sneaky_gophish_upload:latest
    container_name: sneaky_gophish_upload
    volumes:
      - ./uploads:/uploads
    restart: unless-stopped
COMPOSE_EOF
    print_status "docker-compose.yml создан"
}

# Ждём появления пароля в логах (до 120 сек)
# GoPhish печатает пароль только при первом создании БД; при существующей data/gophish.db строки в логах не будет.
wait_for_password() {
    local max_wait=120
    local elapsed=0
    local password=""

    if [ -f "$INSTALL_DIR/data/gophish.db" ] && [ -s "$INSTALL_DIR/data/gophish.db" ]; then
        echo ""
        print_warning "Найдена существующая база: $INSTALL_DIR/data/gophish.db"
        print_warning "Начальный пароль в логах выводится только при первом запуске (новая БД)."
        print_warning "Войдите с прежним паролем или сбросьте: $INSTALL_DIR/manage_gophish.sh reset-admin 'НовыйПароль'"
        return 1
    fi

    print_status "Ожидание запуска GoPhish (может занять до ${max_wait}с)..."
    while [ $elapsed -lt $max_wait ]; do
        password=$($COMPOSE logs sneaky_gophish 2>/dev/null \
            | grep -i "Please login with the username" \
            | tail -1 \
            | grep -o 'password [a-f0-9]*' \
            | cut -d' ' -f2)
        if [ -n "$password" ]; then
            ADMIN_PASSWORD="$password"
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
        printf "."
    done
    echo ""
    return 1
}

# Запуск контейнера
run_container() {
    print_status "Запуск GoPhish контейнера..."
    cd "$INSTALL_DIR"
    $COMPOSE up -d

    if wait_for_password; then
        echo ""
        print_status "GoPhish успешно запущен!"
    else
        echo ""
        print_warning "GoPhish запущен, но пароль ещё не появился в логах."
        print_warning "Используйте: $INSTALL_DIR/manage_gophish.sh password"
    fi
}

# Создание скрипта обновления сертификатов
create_renewal_script() {
    print_status "Создание скрипта обновления сертификатов..."
    cat > "$INSTALL_DIR/renew_ssl.sh" << RENEW_EOF
#!/bin/bash
INSTALL_DIR="$INSTALL_DIR"
DOMAIN_ADMIN="$DOMAIN_ADMIN"

# Тот же каталог, что и у deploy (admin.domain или admin.domain-0001)
pick_le_dir() {
  local best="" best_t=0 d t
  for d in "/etc/letsencrypt/live/\$DOMAIN_ADMIN" /etc/letsencrypt/live/\${DOMAIN_ADMIN}-*; do
    [ -f "\$d/fullchain.pem" ] || continue
    t=\$(stat -c %Y "\$d/fullchain.pem" 2>/dev/null || echo 0)
    if [ "\${t:-0}" -gt "\${best_t:-0}" ]; then best_t=\$t; best=\$d; fi
  done
  [ -n "\$best" ] && echo "\$best" || echo "/etc/letsencrypt/live/\$DOMAIN_ADMIN"
}

certbot renew --quiet
LE_DIR=\$(pick_le_dir)
cp "\$LE_DIR/fullchain.pem" "\$INSTALL_DIR/ssl/admin.crt"
cp "\$LE_DIR/privkey.pem"   "\$INSTALL_DIR/ssl/admin.key"
cp "\$LE_DIR/fullchain.pem" "\$INSTALL_DIR/ssl/phish.crt"
cp "\$LE_DIR/privkey.pem"   "\$INSTALL_DIR/ssl/phish.key"
chmod 644 \$INSTALL_DIR/ssl/*
cd \$INSTALL_DIR && $COMPOSE restart
RENEW_EOF
    chmod +x "$INSTALL_DIR/renew_ssl.sh"

    (crontab -l 2>/dev/null; echo "0 3 * * * $INSTALL_DIR/renew_ssl.sh") | crontab -
    print_status "Автообновление SSL настроено (cron 03:00)"
}

# Итоги
show_summary() {
    # Если пароль не был получён во время run_container — пробуем ещё раз
    if [ -z "${ADMIN_PASSWORD:-}" ]; then
        ADMIN_PASSWORD=$(cd "$INSTALL_DIR" && $COMPOSE logs sneaky_gophish 2>/dev/null \
            | grep -i "Please login with the username" \
            | tail -1 \
            | grep -o 'password [a-f0-9]*' \
            | cut -d' ' -f2)
    fi

    echo ""
    echo "================================================"
    print_status "Развертывание завершено!"
    echo "================================================"
    echo ""
    echo "  Адрес  : https://$DOMAIN_ADMIN:3333"
    echo "  Логин  : admin"
    echo "  Пароль : ${ADMIN_PASSWORD:-не получен — запустите: $INSTALL_DIR/manage_gophish.sh password}"
    echo ""
    echo "  Phish Server  : https://$DOMAIN_PHISH (TLS в GoPhish, порт 443)"
    echo "  Upload        : https://$DOMAIN_PHISH/upload (прокси в GoPhish → Flask)"
    echo "  Uploaded files: $INSTALL_DIR/uploads/"
    echo ""
    if [ "${SSL_TYPE:-}" = "selfsigned" ]; then
        echo "------------------------------------------------"
        print_warning "Используется self-signed сертификат (браузер покажет предупреждение)."
        print_warning "После настройки DNS и открытия порта 80 запустите:"
        print_warning "  $INSTALL_DIR/manage_gophish.sh renew-ssl"
        echo ""
    fi
    echo "  Управление:"
    echo "    $INSTALL_DIR/manage_gophish.sh status"
    echo "    $INSTALL_DIR/manage_gophish.sh logs"
    echo "    $INSTALL_DIR/manage_gophish.sh password"
    echo "    $INSTALL_DIR/manage_gophish.sh restart"
    echo "    $INSTALL_DIR/manage_gophish.sh backup"
    echo "================================================"
}

main() {
    echo "Sneaky GoPhish Deployment Script"
    echo ""

    check_root
    install_dependencies
    create_directories
    build_image
    # config + compose до SSL: иначе docker compose down не выполняется и порт 80 остаётся занят nginx
    create_config
    create_docker_compose
    generate_ssl
    run_container
    create_renewal_script
    show_summary
}

main "$@"
