# Используем официальный образ Node.js
FROM node:18-alpine

# Устанавливаем рабочую директорию
WORKDIR /app

# Устанавливаем системные зависимости для FFmpeg
RUN apk add --no-cache \
    ffmpeg \
    curl \
    ca-certificates

# Копируем файлы зависимостей
COPY package*.json ./

# Устанавливаем зависимости
RUN npm ci --only=production && npm cache clean --force

# Копируем исходный код
COPY . .

# Создаем необходимые директории
RUN mkdir -p logs streams/temp streams/segments streams/cache config

# Устанавливаем права доступа
RUN chown -R node:node /app

# Переключаемся на непривилегированного пользователя
USER node

# Открываем порт
EXPOSE 3001

# Запускаем приложение
CMD ["node", "src/index.js"]