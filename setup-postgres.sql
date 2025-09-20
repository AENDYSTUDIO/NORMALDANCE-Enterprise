-- NORMALDANCE Production PostgreSQL Setup

-- Create database
CREATE DATABASE normaldance_production;

-- Create user
CREATE USER normaldance_user WITH PASSWORD 'ndt_prod_2024_secure';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE normaldance_production TO normaldance_user;

-- Connect to database
\c normaldance_production;

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO normaldance_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO normaldance_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO normaldance_user;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";