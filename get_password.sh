#!/bin/bash

# Скрипт для получения пароля GoPhish

cd /root/sneaky_gophish

echo "🔥 Информация о GoPhish 🔥"
echo ""

# Проверяем статус контейнера
if docker-compose ps | grep -q "Up"; then
    echo "✅ Статус: GoPhish работает"
    
    # Получаем пароль
    password=$(docker-compose logs sneaky_gophish | grep password | tail -1 | grep -o 'password [a-f0-9]*' | cut -d' ' -f2)
    
    if [ -n "$password" ]; then
        echo "🔑 Логин: admin"
        echo "🔑 Пароль: $password"
    else
        echo "❌ Не удалось получить пароль"
        echo "Попробуйте: docker-compose logs sneaky_gophish | grep password"
    fi
    
    echo ""
    echo "🌐 Admin Panel: https://admin.trendcommunity.org:3333"
    echo "🌐 Phish Server: https://trendcommunity.org"
    
else
    echo "❌ Статус: GoPhish не запущен"
    echo "Запустите: docker-compose up -d"
fi
