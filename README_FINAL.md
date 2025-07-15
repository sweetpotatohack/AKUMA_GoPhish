# 🔥 Sneaky GoPhish - Полная Автоматизация от Фени! 🔥

## 🎯 Что это?
Полностью автоматизированная система для развертывания Sneaky GoPhish с SSL сертификатами Let's Encrypt и удобным управлением.

## 🚀 Быстрая установка:

### Вариант 1: Автоматическая установка
```bash
wget -O deploy_gophish.sh https://raw.githubusercontent.com/your-repo/deploy_gophish.sh
chmod +x deploy_gophish.sh
./deploy_gophish.sh
```

### Вариант 2: Ручная установка
```bash
git clone https://github.com/puzzlepeaches/sneaky_gophish
cd sneaky_gophish
chmod +x deploy_gophish.sh
./deploy_gophish.sh
```

## 📋 Что включено:
- **deploy_gophish.sh** - Основной скрипт установки
- **manage_gophish.sh** - Скрипт управления
- **get_password.sh** - Получение пароля
- **status.sh** - Показ статуса
- **renew_ssl.sh** - Обновление SSL

## 🛠️ Управление системой:

### Основные команды:
```bash
# Показать статус
./manage_gophish.sh status

# Получить пароль
./manage_gophish.sh password

# Перезапустить
./manage_gophish.sh restart

# Показать логи
./manage_gophish.sh logs

# Обновить SSL
./manage_gophish.sh renew-ssl

# Создать бэкап
./manage_gophish.sh backup
```

## 🔐 Доступ к системе:
- **Admin Panel**: https://admin.trendcommunity.org:3333
- **Phish Server**: https://trendcommunity.org
- **Логин**: admin
- **Пароль**: получить командой `./manage_gophish.sh password`

## 📁 Структура проекта:
```
/root/sneaky_gophish/
├── deploy_gophish.sh      # Автоматическая установка
├── manage_gophish.sh      # Управление системой
├── get_password.sh        # Получение пароля
├── status.sh             # Статус системы
├── renew_ssl.sh          # Обновление SSL
├── docker-compose.yml    # Docker конфигурация
├── config.json          # Конфигурация GoPhish
├── ssl/                 # SSL сертификаты
│   ├── admin.crt
│   ├── admin.key
│   ├── phish.crt
│   └── phish.key
└── README.md
```

## 🔄 Автоматизация:
- ✅ Автоматическая установка всех зависимостей
- ✅ Генерация SSL сертификатов Let's Encrypt
- ✅ Настройка автообновления сертификатов (cron)
- ✅ Готовые скрипты управления
- ✅ Автоматический бэкап базы данных

## ⚠️ Требования:
- Ubuntu/Debian Linux
- Root доступ
- Интернет соединение
- Открытые порты: 80, 443, 3333
- DNS записи для доменов

## 🎯 Особенности Sneaky GoPhish:
- Убраны заголовки X-Gophish-*
- Изменен Server Name
- Изменен параметр recipient (rid → id)
- Кастомная 404 страница
- Обход security решений

## 🔧 Решение проблем:

### Проблема с портами:
```bash
# Проверить занятые порты
netstat -tlnp | grep -E ":80|:443|:3333"

# Остановить мешающие сервисы
systemctl stop nginx apache2
```

### Проблема с SSL:
```bash
# Перегенерировать сертификаты
certbot delete --cert-name admin.trendcommunity.org
./manage_gophish.sh renew-ssl
```

### Проблема с контейнером:
```bash
# Пересобрать контейнер
docker-compose down
docker rmi sneaky_gophish
docker build -t sneaky_gophish .
docker-compose up -d
```

## 📞 Полезные команды:

### Docker управление:
```bash
# Статус контейнеров
docker-compose ps

# Логи в реальном времени
docker-compose logs -f sneaky_gophish

# Зайти в контейнер
docker exec -it sneaky_gophish_ssl /bin/bash

# Перезапустить контейнер
docker-compose restart
```

### SSL управление:
```bash
# Проверить статус сертификатов
certbot certificates

# Обновить сертификаты
certbot renew

# Проверить срок действия
openssl x509 -in /etc/letsencrypt/live/admin.trendcommunity.org/fullchain.pem -noout -dates
```

## 🚨 Безопасность:
- Используй только для легального пентестинга
- Не забывай менять пароли
- Регулярно обновляй систему
- Мониторь логи на предмет подозрительной активности

## 🔥 Быстрый старт для ленивых:
```bash
# Одна команда для всего
curl -sSL https://your-domain.com/deploy_gophish.sh | bash

# Получить пароль
./manage_gophish.sh password

# Проверить статус
./manage_gophish.sh status
```

### Как говорил мой дед-автоматизатор:
*"Лучший скрипт - это тот, который работает без твоего участия!"*

---
**Made with ❤️ и кучей кофе by Феня**

**Используй с умом, не будь долбоебом!** 🔥
