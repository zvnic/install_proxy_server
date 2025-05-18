.PHONY: help build build-nc up down restart logs shell test clean migrate init prune

# Переменные
PROJECT_NAME=bookurl-service
COMPOSE_FILE=docker-compose.yml
APP_SERVICE=app
DB_SERVICE=db

# Цвета для вывода
GREEN=\033[0;32m
RED=\033[0;31m
YELLOW=\033[0;33m
NC=\033[0m # No Color

# Помощь (команда по умолчанию)
help:
	@echo "$(GREEN)Доступные команды:$(NC)"
	@echo "  make build      - Собрать образы Docker"
	@echo "  make build-nc   - Собрать образы без кэша"
	@echo "  make up         - Запустить все сервисы"
	@echo "  make down       - Остановить все сервисы"
	@echo "  make restart    - Перезапустить все сервисы"
	@echo "  make logs       - Показать логи всех сервисов"
	@echo "  make logs-app   - Показать логи приложения"
	@echo "  make shell      - Войти в контейнер приложения"
	@echo "  make shell-db   - Войти в контейнер БД"
	@echo "  make test       - Запустить тесты"
	@echo "  make clean      - Очистить volumes и остановить контейнеры"
	@echo "  make prune      - Удалить неиспользуемые образы и слои"
	@echo "  make rebuild    - Пересобрать без кэша и очистить старые слои"
	@echo "  make migrate    - Выполнить миграции БД"
	@echo "  make init       - Инициализация проекта (build + up)"
	@echo "  make ps         - Показать запущенные контейнеры"
	@echo "  make db-backup  - Создать резервную копию БД"
	@echo "  make db-restore - Восстановить БД из резервной копии"

# Инициализация проекта
init:
	@echo "$(GREEN)Инициализация проекта...$(NC)"
	@make build
	@make up
	@echo "$(GREEN)Проект успешно инициализирован!$(NC)"
	@echo "API доступен по адресу: http://localhost:$(shell grep API_PORT .env | cut -d '=' -f2)"
	@echo "pgAdmin доступен по адресу: http://localhost:$(shell grep PGADMIN_PORT .env | cut -d '=' -f2)"

# Сборка образов
build:
	@echo "$(GREEN)Сборка Docker образов...$(NC)"
	docker-compose build

# Сборка образов без кэша
build-nc:
	@echo "$(YELLOW)Сборка Docker образов без кэша...$(NC)"
	docker-compose build --no-cache

# Запуск сервисов
up:
	@echo "$(GREEN)Запуск сервисов...$(NC)"
	docker-compose up -d
	@make ps

# Остановка сервисов
down:
	@echo "$(RED)Остановка сервисов...$(NC)"
	docker-compose down

# Перезапуск сервисов
restart:
	@echo "$(GREEN)Перезапуск сервисов...$(NC)"
	@make down
	@make up

# Логи всех сервисов
logs:
	docker-compose logs -f

# Логи приложения
logs-app:
	docker-compose logs -f $(APP_SERVICE)

# Вход в контейнер приложения
shell:
	@echo "$(GREEN)Вход в контейнер приложения...$(NC)"
	docker-compose exec $(APP_SERVICE) /bin/bash

# Вход в контейнер БД
shell-db:
	@echo "$(GREEN)Вход в PostgreSQL...$(NC)"
	docker-compose exec $(DB_SERVICE) psql -U $(shell grep POSTGRES_USER .env | cut -d '=' -f2) -d $(shell grep POSTGRES_DB .env | cut -d '=' -f2)

# Запуск тестов
test:
	@echo "$(GREEN)Запуск тестов...$(NC)"
	docker-compose exec $(APP_SERVICE) pytest

# Очистка
clean:
	@echo "$(RED)Остановка контейнеров и удаление volumes...$(NC)"
	docker-compose down -v
	@echo "$(GREEN)Очистка завершена!$(NC)"

# Безопасная очистка неиспользуемых образов и слоев
prune:
	@echo "$(YELLOW)Безопасная очистка неиспользуемых образов и слоев...$(NC)"
	@echo "$(YELLOW)Сохранение используемых образов...$(NC)"
	@docker-compose ps -q | xargs -I {} docker inspect {} --format='{{.Image}}' > .active_images.tmp || true
	@cat .active_images.tmp | sort | uniq > .active_images_unique.tmp
	@echo "$(YELLOW)Удаление неиспользуемых образов проекта...$(NC)"
	docker images | grep "$(PROJECT_NAME)" | awk '{print $$3}' | while read img; do \
		if ! grep -q "$$img" .active_images_unique.tmp 2>/dev/null; then \
			echo "Удаление образа: $$img"; \
			docker rmi $$img 2>/dev/null || true; \
		fi; \
	done
	@echo "$(YELLOW)Удаление висячих образов...$(NC)"
	docker image prune -f
	@echo "$(YELLOW)Удаление неиспользуемых слоев сборки...$(NC)"
	docker builder prune -f
	@rm -f .active_images.tmp .active_images_unique.tmp
	@echo "$(GREEN)Очистка завершена!$(NC)"
	@docker images | grep "$(PROJECT_NAME)" || echo "Нет образов проекта"

# Полная пересборка без кэша с очисткой
rebuild:
	@echo "$(YELLOW)Полная пересборка проекта...$(NC)"
	@echo "$(RED)Остановка сервисов...$(NC)"
	@make down
	@echo "$(YELLOW)Удаление старых образов проекта...$(NC)"
	@docker images | grep "$(PROJECT_NAME)" | awk '{print $$3}' | xargs docker rmi -f 2>/dev/null || true
	@echo "$(YELLOW)Сборка без кэша...$(NC)"
	@make build-nc
	@echo "$(YELLOW)Очистка неиспользуемых слоев...$(NC)"
	@make prune
	@echo "$(GREEN)Запуск сервисов...$(NC)"
	@make up
	@echo "$(GREEN)Пересборка завершена!$(NC)"

# Обновление кода и пересборка минимальная
update:
	@echo "$(GREEN)Обновление и пересборка приложения...$(NC)"
	git pull
	@make build
	@make restart
	@make prune

# Информация о дисковом пространстве Docker
docker-stats:
	@echo "$(GREEN)Использование дискового пространства Docker:$(NC)"
	docker system df
	@echo "\n$(GREEN)Образы проекта:$(NC)"
	docker images | grep -E "(REPOSITORY|$(PROJECT_NAME))" || echo "Нет образов проекта"
	@echo "\n$(GREEN)Возможность освобождения места:$(NC)"
	docker system df | grep -E "(TYPE|Images)"

# Миграции БД
migrate:
	@echo "$(GREEN)Выполнение миграций...$(NC)"
	docker-compose exec $(APP_SERVICE) python -c "from app.database import engine, Base; import asyncio; asyncio.run(Base.metadata.create_all(bind=engine))"

# Показать запущенные контейнеры
ps:
	@echo "$(GREEN)Запущенные контейнеры:$(NC)"
	docker-compose ps

# Резервное копирование БД
db-backup:
	@echo "$(GREEN)Создание резервной копии БД...$(NC)"
	mkdir -p backups
	docker-compose exec -T $(DB_SERVICE) pg_dump -U $(shell grep POSTGRES_USER .env | cut -d '=' -f2) -d $(shell grep POSTGRES_DB .env | cut -d '=' -f2) > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Резервная копия создана в папке backups/$(NC)"

# Восстановление БД из резервной копии
db-restore:
	@echo "$(GREEN)Восстановление БД из резервной копии...$(NC)"
	@read -p "Введите имя файла резервной копии (из папки backups): " backup_file; \
	docker-compose exec -T $(DB_SERVICE) psql -U $(shell grep POSTGRES_USER .env | cut -d '=' -f2) -d $(shell grep POSTGRES_DB .env | cut -d '=' -f2) < backups/$$backup_file
	@echo "$(GREEN)БД восстановлена!$(NC)"

# Быстрый перезапуск приложения
restart-app:
	@echo "$(GREEN)Перезапуск приложения...$(NC)"
	docker-compose restart $(APP_SERVICE)
	docker-compose logs -f $(APP_SERVICE)

# Проверка состояния сервисов
health:
	@echo "$(GREEN)Проверка состояния сервисов...$(NC)"
	@docker-compose ps | grep -E "($(APP_SERVICE)|$(DB_SERVICE)|pgadmin)" | awk '{print $$1, $$NF}'

# Обновление зависимостей
update-deps:
	@echo "$(GREEN)Обновление зависимостей...$(NC)"
	docker-compose exec $(APP_SERVICE) pip install -r requirements.txt --upgrade

# Форматирование кода
format:
	@echo "$(GREEN)Форматирование кода...$(NC)"
	docker-compose exec $(APP_SERVICE) black app/
	docker-compose exec $(APP_SERVICE) isort app/

# Линтинг кода
lint:
	@echo "$(GREEN)Проверка кода...$(NC)"
	docker-compose exec $(APP_SERVICE) flake8 app/
	docker-compose exec $(APP_SERVICE) mypy app/

# Создание новой сущности по шаблону BookURL
new-entity:
	@read -p "Введите название новой сущности (например: Product): " entity_name; \
	entity_lower=$$(echo $$entity_name | tr '[:upper:]' '[:lower:]'); \
	mkdir -p app/$$entity_lower; \
	echo "$(GREEN)Создание новой сущности $$entity_name...$(NC)"; \
	cp -r app/bookurl/* app/$$entity_lower/; \
	find app/$$entity_lower -type f -exec sed -i "s/BookURL/$$entity_name/g" {} \;; \
	find app/$$entity_lower -type f -exec sed -i "s/bookurl/$$entity_lower/g" {} \;; \
	echo "$(GREEN)Сущность $$entity_name создана в app/$$entity_lower/$(NC)"

# Просмотр переменных окружения
env:
	@echo "$(GREEN)Переменные окружения:$(NC)"
	@cat .env

# Развертывание в production
deploy:
	@echo "$(GREEN)Развертывание в production...$(NC)"
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Откат к предыдущей версии
rollback:
	@echo "$(RED)Откат к предыдущей версии...$(NC)"
	docker-compose down
	git checkout HEAD~1
	@make build
	@make up
