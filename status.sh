#!/bin/bash

# Скрипт для показа полной информации о GoPhish

echo "🔥 Феня's GoPhish Status Dashboard 🔥"
echo "======================================="
echo ""

cd /root/sneaky_gophish

# Проверяем статус контейнера
echo "📊 Статус контейнера:"
docker-compose ps
echo ""

# Проверяем порты
echo "🔌 Используемые порты:"
netstat -tlnp | grep -E ":3333|:443" 2>/dev/null || ss -tlnp | grep -E ":3333|:443"
echo ""

# Получаем пароль
echo "🔑 Данные для входа:"
password=$(docker-compose logs sneaky_gophish | grep password | tail -1 | grep -o 'password [a-f0-9]*' | cut -d' ' -f2 2>/dev/null)
if [ -n "$password" ]; then
    echo "   Логин: admin"
    echo "   Пароль: $password"
else
    echo "   ❌ Не удалось получить пароль"
fi
echo ""

# Проверяем SSL сертификаты
echo "🔒 SSL сертификаты:"
if [ -f "/etc/letsencrypt/live/admin.trendcommunity.org/fullchain.pem" ]; then
    expiry=$(openssl x509 -in /etc/letsencrypt/live/admin.trendcommunity.org/fullchain.pem -noout -dates | grep "notAfter" | cut -d= -f2)
    echo "   ✅ Сертификаты валидны до: $expiry"
else
    echo "   ❌ SSL сертификаты не найдены"
fi
echo ""

# URLs
echo "🌐 Доступ к сервисам:"
echo "   Admin Panel: https://admin.trendcommunity.org:3333"
echo "   Phish Server: https://trendcommunity.org"
echo ""

# Последние логи
echo "📝 Последние логи:"
docker-compose logs sneaky_gophish | tail -5
echo ""

echo "🛠️ Управление:"
echo "   Перезапуск: docker-compose restart"
echo "   Остановка: docker-compose down"
echo "   Логи: docker-compose logs -f sneaky_gophish"
echo "   Обновить SSL: ./renew_ssl.sh"
