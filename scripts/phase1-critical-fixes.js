#!/usr/bin/env node

/**
 * NORMALDANCE Phase 1: Критические исправления
 * Автоматизированный скрипт для исправления критических проблем
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🚀 NORMALDANCE Phase 1: Критические исправления');
console.log('================================================');

const fixes = {
  typescript: false,
  dependencies: false,
  database: false,
  build: false
};

// 1. Исправление TypeScript конфигурации
function fixTypeScriptConfig() {
  console.log('\n📝 1. Исправление TypeScript конфигурации...');
  
  const tsconfigPath = path.join(process.cwd(), 'tsconfig.json');
  const tsconfig = {
    "compilerOptions": {
      "target": "ES2017",
      "lib": ["dom", "dom.iterable", "esnext"],
      "allowJs": true,
      "skipLibCheck": true,
      "strict": true,
      "noEmit": true,
      "noImplicitAny": true,
      "esModuleInterop": true,
      "module": "esnext",
      "moduleResolution": "bundler",
      "resolveJsonModule": true,
      "isolatedModules": true,
      "jsx": "preserve",
      "incremental": true,
      "plugins": [{ "name": "next" }],
      "paths": { "@/*": ["./src/*"] }
    },
    "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
    "exclude": ["node_modules", "mobile-app/**", "trash/**", "coverage/**"]
  };

  fs.writeFileSync(tsconfigPath, JSON.stringify(tsconfig, null, 2));
  console.log('✅ TypeScript конфигурация обновлена');
  fixes.typescript = true;
}

// 2. Синхронизация зависимостей
function syncDependencies() {
  console.log('\n📦 2. Синхронизация зависимостей...');
  
  try {
    // Очистка кеша
    execSync('npm cache clean --force', { stdio: 'inherit' });
    
    // Удаление node_modules и lock файлов
    if (fs.existsSync('node_modules')) {
      execSync('rm -rf node_modules', { stdio: 'inherit' });
    }
    if (fs.existsSync('package-lock.json')) {
      fs.unlinkSync('package-lock.json');
    }
    
    // Установка зависимостей
    execSync('npm install', { stdio: 'inherit' });
    
    console.log('✅ Зависимости синхронизированы');
    fixes.dependencies = true;
  } catch (error) {
    console.error('❌ Ошибка синхронизации зависимостей:', error.message);
  }
}

// 3. Унификация стратегии БД
function unifyDatabaseStrategy() {
  console.log('\n🗄️ 3. Унификация стратегии БД...');
  
  const schemaPath = path.join(process.cwd(), 'prisma', 'schema.prisma');
  let schema = fs.readFileSync(schemaPath, 'utf8');
  
  // Убеждаемся что используется PostgreSQL
  if (!schema.includes('provider = "postgresql"')) {
    schema = schema.replace(/provider = ".*"/, 'provider = "postgresql"');
    fs.writeFileSync(schemaPath, schema);
  }
  
  // Генерация Prisma клиента
  try {
    execSync('npx prisma generate', { stdio: 'inherit' });
    console.log('✅ База данных унифицирована (PostgreSQL)');
    fixes.database = true;
  } catch (error) {
    console.error('❌ Ошибка генерации Prisma клиента:', error.message);
  }
}

// 4. Проверка сборки
function testBuild() {
  console.log('\n🔨 4. Проверка сборки...');
  
  try {
    execSync('npm run type-check', { stdio: 'inherit' });
    execSync('npm run build', { stdio: 'inherit' });
    console.log('✅ Сборка успешна');
    fixes.build = true;
  } catch (error) {
    console.error('❌ Ошибка сборки:', error.message);
  }
}

// 5. Создание отчета
function generateReport() {
  console.log('\n📊 Отчет Phase 1:');
  console.log('==================');
  
  const results = Object.entries(fixes).map(([key, status]) => {
    const emoji = status ? '✅' : '❌';
    const name = {
      typescript: 'TypeScript конфигурация',
      dependencies: 'Синхронизация зависимостей', 
      database: 'Унификация БД',
      build: 'Проверка сборки'
    }[key];
    return `${emoji} ${name}`;
  });
  
  results.forEach(result => console.log(result));
  
  const successCount = Object.values(fixes).filter(Boolean).length;
  const totalCount = Object.keys(fixes).length;
  
  console.log(`\n📈 Прогресс: ${successCount}/${totalCount} (${Math.round(successCount/totalCount*100)}%)`);
  
  if (successCount === totalCount) {
    console.log('\n🎉 Phase 1 завершена успешно!');
    console.log('Готов к переходу к Phase 2: Оптимизация производительности');
  } else {
    console.log('\n⚠️ Требуется ручное вмешательство для завершения Phase 1');
  }
}

// Основная функция
async function main() {
  try {
    fixTypeScriptConfig();
    syncDependencies();
    unifyDatabaseStrategy();
    testBuild();
    generateReport();
  } catch (error) {
    console.error('❌ Критическая ошибка:', error.message);
    process.exit(1);
  }
}

// Запуск
if (require.main === module) {
  main();
}

module.exports = { main, fixes };