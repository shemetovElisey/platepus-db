# Инструкция по загрузке дампа на удаленный сервер

## Быстрый способ (рекомендуется)

### Шаг 1: Подготовка дампа

Убедитесь, что у вас есть дамп в формате `.gz` (12 ГБ в вашем случае).

### Шаг 2: Загрузка на сервер

Используйте скрипт `upload-dump.sh`:

```bash
cd platepus-db
chmod +x upload-dump.sh
./upload-dump.sh /path/to/your/dump.gz user@your-server.com:/opt/platepus-db/mongo-init/dump/
```

**Пример:**
```bash
./upload-dump.sh ~/Downloads/platepus-dump.gz root@192.168.1.100:/opt/platepus-db/mongo-init/dump/
```

### Шаг 3: На удаленном сервере

Подключитесь к серверу и распакуйте дамп:

```bash
# SSH на сервер
ssh user@your-server.com

# Перейти в директорию проекта
cd /opt/platepus-db

# Распаковать дамп
cd mongo-init/dump
gunzip dump.gz
# Или если это tar.gz:
tar -xzf dump.gz
```

### Шаг 4: Импорт дампа

```bash
# Вернуться в корень проекта
cd /opt/platepus-db

# Остановить MongoDB (если запущена)
docker compose down

# Удалить существующий volume (если нужно начать с чистого листа)
docker volume rm platepus_mongo_data

# Запустить MongoDB (дамп импортируется автоматически)
docker compose up -d

# Проверить логи импорта
docker compose logs -f mongo
```

## Альтернативные способы

### Способ 1: Использование rsync (для больших файлов)

```bash
# Загрузить с прогресс-баром
rsync -avz --progress dump.gz user@server:/opt/platepus-db/mongo-init/dump/
```

### Способ 2: Использование extract-and-import.sh

Если дамп уже загружен на сервер:

```bash
ssh user@server
cd /opt/platepus-db
chmod +x extract-and-import.sh
./extract-and-import.sh mongo-init/dump/dump.gz
```

### Способ 3: Прямая загрузка через scp

```bash
# Загрузить дамп
scp dump.gz user@server:/opt/platepus-db/mongo-init/dump/

# Подключиться к серверу
ssh user@server

# Распаковать
cd /opt/platepus-db/mongo-init/dump
gunzip dump.gz
```

## Проверка успешного импорта

После импорта проверьте:

```bash
# Подключиться к MongoDB
docker compose exec mongo mongosh platepus

# Проверить количество коллекций
db.getCollectionNames()

# Проверить размер базы данных
db.stats(1024*1024)  # Размер в МБ
```

## Решение проблем

### Ошибка: "No space left on device"

Убедитесь, что на сервере достаточно места:
- Распакованный дамп: ~24-48 ГБ
- MongoDB данные: +20-30% для индексов
- Итого нужно: минимум 60-80 ГБ свободного места

```bash
# Проверить свободное место
df -h

# Очистить неиспользуемые Docker данные
docker system prune -a
```

### Ошибка: "Connection refused"

Проверьте, что MongoDB запущена и доступна:

```bash
docker compose ps
docker compose logs mongo
```

### Медленная загрузка

Для больших файлов (12 ГБ) используйте:
- `rsync` вместо `scp` (может продолжить при обрыве)
- Сжатие с максимальным уровнем: `gzip -9 dump`
- Загрузку в несколько потоков (если поддерживается)

## Безопасность

⚠️ **Важно:**
- Используйте SSH ключи вместо паролей
- Ограничьте доступ к серверу через firewall
- Не передавайте пароли в открытом виде
- Используйте VPN или приватную сеть для передачи данных

## Пример полного процесса

```bash
# 1. Локально: загрузить дамп
cd platepus-db
./upload-dump.sh ~/dump.gz user@server:/opt/platepus-db/mongo-init/dump/

# 2. На сервере: распаковать и импортировать
ssh user@server
cd /opt/platepus-db
docker compose down
docker volume rm platepus_mongo_data  # Опционально
cd mongo-init/dump && gunzip dump.gz && cd ../..
docker compose up -d

# 3. Проверить импорт
docker compose logs -f mongo
# Дождаться сообщения "MongoDB dump imported successfully"
```

