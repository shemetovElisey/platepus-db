# Platepus Database Repository

Отдельный репозиторий для MongoDB базы данных проекта Platepus.

## Структура

```
platepus-db/
├── docker-compose.yml          # Конфигурация MongoDB
├── mongo-init/
│   ├── 01-import-dump.sh       # Скрипт автоматического импорта дампа
│   └── dump/                   # Директория для дампа БД
├── upload-dump.sh              # Скрипт для загрузки дампа на удаленный сервер
├── extract-and-import.sh       # Скрипт для распаковки и импорта дампа
└── README.md                   # Этот файл
```

## Быстрый старт

### Локальный запуск (без аутентификации)

```bash
# Запустить MongoDB
docker compose up -d

# Проверить статус
docker compose ps

# Просмотр логов
docker compose logs -f mongo
```

### Production запуск (с аутентификацией)

```bash
# Создайте .env файл с учетными данными
cat > .env << 'EOF'
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_secure_password
EOF

# Запустите с production конфигурацией
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d

# Проверьте статус
docker compose ps
```

**См. также:**
- `docker-compose.production.yml` - production конфигурация
- `CONNECTION_GUIDE.md` - руководство по подключению

### Подключение к базе

```bash
# Подключиться через mongosh
docker compose exec mongo mongosh platepus

# Или напрямую
mongosh mongodb://localhost:27017/platepus
```

## Загрузка дампа на удаленный сервер

### Вариант 1: Использование скрипта upload-dump.sh

```bash
# Сделать скрипт исполняемым
chmod +x upload-dump.sh

# Загрузить дамп (замените на ваши данные)
./upload-dump.sh /path/to/dump.gz user@example.com:/opt/platepus-db/mongo-init/dump/
```

### Вариант 2: Прямая загрузка через scp

```bash
# Загрузить сжатый дамп
scp dump.gz user@example.com:/opt/platepus-db/mongo-init/dump/

# Подключиться к серверу
ssh user@example.com

# Распаковать дамп
cd /opt/platepus-db
gunzip mongo-init/dump/dump.gz
# Или если это tar.gz:
tar -xzf mongo-init/dump/dump.gz -C mongo-init/dump/
```

### Вариант 3: Использование rsync (для больших файлов)

```bash
# Загрузить с прогресс-баром
rsync -avz --progress dump.gz user@example.com:/opt/platepus-db/mongo-init/dump/
```

### Вариант 4: Использование extract-and-import.sh на сервере

```bash
# На удаленном сервере
cd /opt/platepus-db
chmod +x extract-and-import.sh
./extract-and-import.sh mongo-init/dump/dump.gz
```

## Импорт дампа

### Автоматический импорт (при первом запуске)

Если дамп находится в `mongo-init/dump/`, он будет автоматически импортирован при первом запуске MongoDB:

```bash
# Остановить MongoDB (если запущена)
docker compose down

# Удалить существующий volume (если нужно начать с чистого листа)
docker volume rm platepus_mongo_data

# Запустить MongoDB (дамп импортируется автоматически)
docker compose up -d
```

### Ручной импорт

```bash
# Если MongoDB уже запущена
docker compose exec mongo mongorestore --db=platepus /docker-entrypoint-initdb.d/dump
```

## Формат дампа

Дамп должен быть в формате, который понимает `mongorestore`:
- Распакованный (не .gz)
- Стандартная структура директорий с .bson файлами

Если у вас сжатый дамп (.gz), распакуйте его перед помещением в `mongo-init/dump/`.

## Переменные окружения

По умолчанию используется:
- База данных: `platepus`
- Порт: `27017`

Для изменения создайте файл `.env`:

```env
MONGO_INITDB_DATABASE=platepus
MONGO_PORT=27017
```

## Подключение приложения

Приложение должно использовать переменную окружения `DATABASE_URL`:

```bash
DATABASE_URL=mongodb://localhost:27017/platepus
```

Или для удаленного сервера:

```bash
DATABASE_URL=mongodb://user:password@host:27017/platepus
```

## Резервное копирование

### Создание дампа

```bash
# Создать дамп
docker compose exec mongo mongodump --db=platepus --out=/data/backup

# Скопировать дамп из контейнера
docker compose cp mongo:/data/backup ./backup

# Сжать дамп
tar -czf backup-$(date +%Y%m%d).tar.gz backup/
```

### Восстановление из дампа

```bash
# Скопировать дамп в контейнер
docker compose cp backup/ mongo:/data/backup

# Восстановить
docker compose exec mongo mongorestore --db=platepus /data/backup/platepus
```

## Мониторинг

```bash
# Статистика использования
docker compose exec mongo mongosh --eval "db.stats()"

# Список коллекций
docker compose exec mongo mongosh platepus --eval "db.getCollectionNames()"

# Размер базы данных
docker compose exec mongo mongosh platepus --eval "db.stats(1024*1024)"
```

## Производительность

Для оптимизации MongoDB на продакшене рекомендуется:

1. Настроить `cacheSizeGB` в `mongod.conf`
2. Использовать SSD диски
3. Настроить индексы для частых запросов
4. Мониторить использование ресурсов

## Безопасность

⚠️ **Важно для продакшена:**

1. ✅ **Настроить аутентификацию MongoDB** - используйте `docker-compose.production.yml`
2. ✅ **Использовать SSL/TLS для соединений**
3. ✅ **Ограничить доступ по сети (firewall)**
4. ✅ **Регулярно делать бэкапы**
5. ✅ **Не хранить пароли в открытом виде** - используйте `.env` файл (добавлен в `.gitignore`)

### Настройка аутентификации

**Используйте готовую production конфигурацию:**

```bash
# Создайте .env файл с паролями
cat > .env << 'EOF'
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_very_secure_password_here
EOF

# Запустите с аутентификацией
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

**Подробнее см.:**
- `docker-compose.production.yml` - готовая конфигурация
- `CONNECTION_GUIDE.md` - руководство по подключению с примерами

## Очистка базы данных

### Удаление продуктов без данных о питательности

Скрипт `remove-products-without-nutrition.sh` позволяет удалить из базы данных все продукты, у которых нет валидных данных об энергетической ценности (калориях) и макронутриентах (БЖУ).

**⚠️ ВАЖНО: Эта операция НЕОБРАТИМА! Обязательно сделайте резервную копию перед удалением!**

#### Создание резервной копии

```bash
# Создать дамп перед удалением
docker compose exec mongo mongodump --db=platepus --out=/data/backup-before-cleanup
docker compose cp mongo:/data/backup-before-cleanup ./backup-before-cleanup
```

#### Использование скрипта

```bash
# 1. Сначала выполните "сухой прогон" (dry run) - посмотрите, что будет удалено
./remove-products-without-nutrition.sh mongodb://localhost:27017/platepus --dry-run

# 2. Если результат устраивает, выполните реальное удаление
./remove-products-without-nutrition.sh mongodb://localhost:27017/platepus --confirm
```

#### Что удаляется

Скрипт удаляет продукты, у которых:
- Нет объекта `nutriments`, ИЛИ
- Нет валидных данных об энергетической ценности (ккал или кДж), И
- Нет валидных данных о макронутриентах (белки, жиры или углеводы)

#### Примеры

```bash
# Локальная база данных (без аутентификации)
./remove-products-without-nutrition.sh mongodb://localhost:27017/platepus --dry-run

# С аутентификацией
./remove-products-without-nutrition.sh mongodb://user:password@localhost:27017/platepus --confirm

# Удаленная база данных
./remove-products-without-nutrition.sh mongodb://user:password@remote-host:27017/platepus --confirm
```

## Troubleshooting

### MongoDB не запускается

```bash
# Проверить логи
docker compose logs mongo

# Проверить использование порта
lsof -i :27017
```

### Дамп не импортируется

1. Убедитесь, что дамп распакован
2. Проверьте формат дампа (должен быть mongorestore формат)
3. Проверьте права доступа к файлам
4. Проверьте логи: `docker compose logs mongo`

### Недостаточно места на диске

```bash
# Проверить использование
docker system df

# Очистить неиспользуемые данные
docker system prune -a
```

