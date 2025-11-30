# Руководство по подключению к удаленной базе данных

## Формат Connection String

### Базовый формат
```
mongodb://[username:password@]host[:port][/database][?options]
```

### Примеры

**Без аутентификации:**
```
mongodb://192.168.1.100:27017/platepus
```

**С аутентификацией:**
```
mongodb://admin:password123@192.168.1.100:27017/platepus?authSource=admin
```

**С дополнительными опциями:**
```
mongodb://user:pass@host:27017/platepus?authSource=admin&ssl=true&retryWrites=true
```

## Подключение приложения (Vapor)

### Вариант 1: Переменная окружения

```bash
export DATABASE_URL=mongodb://your-server-ip:27017/platepus
swift run
```

### Вариант 2: Docker Compose с .env файлом

Создайте файл `.env` в директории `platepus`:

```env
DATABASE_URL=mongodb://your-server-ip:27017/platepus
LOG_LEVEL=debug
```

Затем запустите:
```bash
docker compose up app
```

### Вариант 3: Прямо в команде

```bash
DATABASE_URL=mongodb://your-server-ip:27017/platepus docker compose up app
```

## Подключение через mongosh

### Прямое подключение

```bash
mongosh mongodb://your-server-ip:27017/platepus
```

### С аутентификацией

```bash
mongosh mongodb://username:password@your-server-ip:27017/platepus?authSource=admin
```

### Через SSH туннель (рекомендуется для безопасности)

**Шаг 1:** Создайте SSH туннель:
```bash
ssh -L 27017:localhost:27017 user@your-server-ip
```

**Шаг 2:** В другом терминале подключитесь:
```bash
mongosh mongodb://localhost:27017/platepus
```

### Подключение на самом сервере

```bash
# SSH на сервер
ssh user@your-server-ip

# Перейти в директорию проекта
cd /opt/platepus-db

# Подключиться через Docker
docker compose exec mongo mongosh platepus
```

## Настройка безопасности

### 1. Настройка аутентификации MongoDB

Создайте файл `.env` в `platepus-db`:

```env
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_secure_password
```

Запустите с production конфигурацией:
```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

### 2. Настройка Firewall

**Ubuntu/Debian:**
```bash
# Разрешить доступ только с определенных IP
sudo ufw allow from YOUR_APP_SERVER_IP to any port 27017

# Или только локальный доступ (рекомендуется)
# Не открывайте порт 27017 наружу, используйте VPN или SSH туннель
```

**Или в docker-compose.yml измените:**
```yaml
ports:
  - '127.0.0.1:27017:27017'  # Только localhost
```

### 3. Использование VPN или приватной сети

Лучший вариант для продакшена - использовать приватную сеть между серверами или VPN.

## Проверка подключения

### Тест из приложения

```bash
# Запустить приложение с DATABASE_URL
DATABASE_URL=mongodb://your-server-ip:27017/platepus swift run

# Проверить логи - не должно быть ошибок подключения
```

### Тест через mongosh

```bash
# Простое подключение
mongosh mongodb://your-server-ip:27017/platepus --eval "db.stats()"

# С аутентификацией
mongosh mongodb://user:pass@your-server-ip:27017/platepus --eval "db.stats()"
```

### Тест из Docker контейнера приложения

```bash
# Запустить контейнер с DATABASE_URL
docker run --rm -e DATABASE_URL=mongodb://your-server-ip:27017/platepus platepus:latest

# Или через docker-compose
DATABASE_URL=mongodb://your-server-ip:27017/platepus docker compose up app
```

## Решение проблем

### Ошибка: "Connection refused"

**Причины:**
1. MongoDB не запущена на сервере
2. Порт 27017 закрыт firewall
3. Неправильный IP адрес

**Решение:**
```bash
# На сервере проверьте
docker compose ps
docker compose logs mongo

# Проверьте доступность порта
telnet your-server-ip 27017
# Или
nc -zv your-server-ip 27017
```

### Ошибка: "Authentication failed"

**Причины:**
1. Неправильный username/password
2. Не указан authSource

**Решение:**
```bash
# Убедитесь, что используете правильный формат
mongodb://username:password@host:27017/platepus?authSource=admin
```

### Ошибка: "Network is unreachable"

**Причины:**
1. Сервер недоступен
2. Проблемы с сетью

**Решение:**
```bash
# Проверьте доступность сервера
ping your-server-ip

# Проверьте маршрут
traceroute your-server-ip
```

## Примеры для разных сценариев

### Локальная разработка (БД на том же компьютере)

```bash
DATABASE_URL=mongodb://localhost:27017/platepus
```

### БД на удаленном сервере (без аутентификации)

```bash
DATABASE_URL=mongodb://192.168.1.100:27017/platepus
```

### БД на удаленном сервере (с аутентификацией)

```bash
DATABASE_URL=mongodb://admin:password123@192.168.1.100:27017/platepus?authSource=admin
```

### БД через SSH туннель

```bash
# Терминал 1: Создать туннель
ssh -L 27017:localhost:27017 user@remote-server

# Терминал 2: Использовать localhost
DATABASE_URL=mongodb://localhost:27017/platepus
```

### БД в Docker сети (оба контейнера на одном сервере)

Если приложение и БД в одной Docker сети:
```bash
DATABASE_URL=mongodb://mongo:27017/platepus
```

## Рекомендации по безопасности

1. ✅ Используйте аутентификацию в продакшене
2. ✅ Не открывайте порт 27017 наружу без необходимости
3. ✅ Используйте VPN или приватную сеть
4. ✅ Используйте SSH туннель для доступа извне
5. ✅ Регулярно обновляйте MongoDB
6. ✅ Используйте сильные пароли
7. ✅ Ограничьте доступ по IP через firewall
8. ✅ Используйте SSL/TLS для соединений (опционально)

