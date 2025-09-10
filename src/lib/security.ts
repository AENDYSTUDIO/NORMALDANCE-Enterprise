// Минимальная библиотека безопасности для исправления уязвимостей

export function sanitizeInput(input: string): string {
  if (!input || typeof input !== 'string') return ''
  return input.replace(/[<>\"'&\n\r]/g, '').slice(0, 1000)
}

export function validateWalletAddress(address: string): boolean {
  if (!address || typeof address !== 'string') return false
  return /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(address)
}

export function safeLog(message: string, data?: Record<string, any>): void {
  const sanitizedData = data ? Object.keys(data).reduce((acc, key) => {
    acc[key] = typeof data[key] === 'string' ? sanitizeInput(data[key]) : data[key]
    return acc
  }, {} as Record<string, any>) : {}
  
  console.log(sanitizeInput(message), sanitizedData)
}

export function validateAmount(amount: number): boolean {
  return typeof amount === 'number' && amount >= 0 && Number.isFinite(amount)
}