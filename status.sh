#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DOMAIN_ADMIN="${DOMAIN_ADMIN:-admin.trendcommunity.org}"
DOMAIN_PHISH="${DOMAIN_PHISH:-trendcommunity.org}"

if docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    echo "Ошибка: Docker Compose не найден."
    exit 1
fi

echo "GoPhish Status Dashboard"
echo "========================"
echo ""

echo "Статус контейнера:"
$COMPOSE ps
echo ""

echo "Используемые порты:"
ss -tlnp | grep -E ":3333|:443" || echo "  Порты не прослушиваются"
echo ""

echo "Данные для входа:"
password=$($COMPOSE logs sneaky_gophish 2>/dev/null | grep -i "password" | tail -1 | grep -o 'password [a-f0-9]*' | cut -d' ' -f2)
if [ -n "$password" ]; then
    echo "  Логин : admin"
    echo "  Пароль: $password"
else
    echo "  Не удалось получить пароль. Проверьте: $COMPOSE logs sneaky_gophish | grep -i password"
fi
echo ""

echo "SSL сертификаты:"
cert_path="/etc/letsencrypt/live/$DOMAIN_ADMIN/fullchain.pem"
if [ -f "$cert_path" ]; then
    expiry=$(openssl x509 -in "$cert_path" -noout -dates 2>/dev/null | grep "notAfter" | cut -d= -f2)
    echo "  Тип   : Let's Encrypt"
    echo "  Истекает: $expiry"
elif [ -f "$SCRIPT_DIR/ssl/admin.crt" ]; then
    expiry=$(openssl x509 -in "$SCRIPT_DIR/ssl/admin.crt" -noout -dates 2>/dev/null | grep "notAfter" | cut -d= -f2)
    echo "  Тип   : Self-signed"
    echo "  Истекает: $expiry"
else
    echo "  SSL сертификаты не найдены"
fi
echo ""

echo "Доступ к сервисам:"
echo "  Admin Panel : https://$DOMAIN_ADMIN:3333"
echo "  Phish Server: https://$DOMAIN_PHISH"
echo ""

echo "Последние логи:"
$COMPOSE logs sneaky_gophish 2>/dev/null | tail -5
echo ""

echo "Управление:"
echo "  $SCRIPT_DIR/manage_gophish.sh restart"
echo "  $SCRIPT_DIR/manage_gophish.sh logs"
echo "  $SCRIPT_DIR/manage_gophish.sh backup"
