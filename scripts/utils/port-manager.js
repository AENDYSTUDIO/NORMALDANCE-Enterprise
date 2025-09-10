const { exec } = require('child_process');

// Проверяем какие порты заняты
function checkPorts() {
  exec('netstat -ano | findstr :300', (error, stdout) => {
    if (error) return;
    
    console.log('🔍 Занятые порты:');
    const lines = stdout.split('\n').filter(line => line.includes('LISTENING'));
    
    lines.forEach(line => {
      const parts = line.trim().split(/\s+/);
      const port = parts[1]?.split(':')[1];
      const pid = parts[4];
      
      if (port && pid) {
        // Получаем имя процесса
        exec(`tasklist /FI "PID eq ${pid}" /FO CSV /NH`, (err, processInfo) => {
          if (!err) {
            const processName = processInfo.split(',')[0]?.replace(/"/g, '');
            console.log(`Port ${port}: PID ${pid} (${processName})`);
          }
        });
      }
    });
  });
}

// Безопасно освобождаем только Node.js процессы
function freeNodePorts() {
  exec('netstat -ano | findstr :300', (error, stdout) => {
    if (error) return;
    
    const lines = stdout.split('\n').filter(line => line.includes('LISTENING'));
    
    lines.forEach(line => {
      const parts = line.trim().split(/\s+/);
      const port = parts[1]?.split(':')[1];
      const pid = parts[4];
      
      if (port && pid) {
        // Проверяем что это Node.js процесс
        exec(`tasklist /FI "PID eq ${pid}" /FO CSV /NH`, (err, processInfo) => {
          if (!err && processInfo.includes('node.exe')) {
            console.log(`🔄 Останавливаю Node.js процесс на порту ${port} (PID: ${pid})`);
            exec(`taskkill /PID ${pid} /F`);
          }
        });
      }
    });
  });
}

// Запускаем проверку
if (process.argv[2] === 'check') {
  checkPorts();
} else if (process.argv[2] === 'free') {
  freeNodePorts();
} else {
  console.log('Использование:');
  console.log('node scripts/port-manager.js check  - проверить порты');
  console.log('node scripts/port-manager.js free   - освободить только Node.js порты');
}