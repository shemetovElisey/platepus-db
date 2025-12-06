# Platepus Database

MongoDB база данных для проекта Platepus.

## Быстрый старт

### Локальный запуск (без аутентификации)

```bash
docker compose up -d
```

### Production (с аутентификацией)

```bash
# Создайте .env файл
cat > .env << 'EOF'
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_secure_password
EOF

# Запустите
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

## Подключение

```bash
# Через mongosh
docker compose exec mongo mongosh platepus

# Или напрямую
mongosh mongodb://localhost:27017/platepus
```

## Конфигурация

- Порт: `127.0.0.1:27017` (только localhost)
- Сеть: `platepus-network`
- Для доступа с IP `5.34.213.116` настройте firewall:
  ```bash
  sudo ufw allow from 5.34.213.116 to any port 27017
  ```

## Подключение приложения

Приложение подключается через Docker сеть:
```
DATABASE_URL=mongodb://mongo:27017/platepus?authSource=admin
```
