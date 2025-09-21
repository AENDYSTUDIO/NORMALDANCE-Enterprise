#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🔧 NORMALDANCE Critical Fixes');

// 1. Install missing dependencies
console.log('📦 Installing dependencies...');
try {
  execSync('npm install', { stdio: 'inherit' });
  console.log('✅ Dependencies installed');
} catch (error) {
  console.error('❌ Failed to install dependencies:', error.message);
}

// 2. Generate Prisma client
console.log('🗄️ Generating Prisma client...');
try {
  execSync('npx prisma generate', { stdio: 'inherit' });
  console.log('✅ Prisma client generated');
} catch (error) {
  console.error('❌ Failed to generate Prisma client:', error.message);
}

// 3. Type check
console.log('🔍 Running type check...');
try {
  execSync('npx tsc --noEmit', { stdio: 'inherit' });
  console.log('✅ Type check passed');
} catch (error) {
  console.error('⚠️ Type check issues found - review and fix manually');
}

// 4. Build test
console.log('🏗️ Testing build...');
try {
  execSync('npm run build', { stdio: 'inherit' });
  console.log('✅ Build successful');
} catch (error) {
  console.error('❌ Build failed - review errors above');
}

console.log('\n🎯 Critical fixes completed!');
console.log('Next steps:');
console.log('1. Review type errors if any');
console.log('2. Test application: npm run dev');
console.log('3. Run tests: npm test');