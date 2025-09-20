-- NORMALDANCE Production Database Setup
-- Выполнить как пользователь postgres

-- Создание базы данных
CREATE DATABASE normaldance_production
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Создание пользователя для production
CREATE USER normaldance_prod WITH PASSWORD 'NDT_db_2024_secure_prod';

-- Предоставление прав
GRANT ALL PRIVILEGES ON DATABASE normaldance_production TO normaldance_prod;

-- Подключение к базе данных
\c normaldance_production;

-- Предоставление прав на схему
GRANT ALL ON SCHEMA public TO normaldance_prod;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO normaldance_prod;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO normaldance_prod;

-- Включение необходимых расширений
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Создание индексов для производительности
-- (будут добавлены после миграций Prisma)