// HTTPS конфигурация для всех API вызовов
export const API_CONFIG = {
  BASE_URL: process.env.NODE_ENV === 'production' 
    ? 'https://api.normaldance.com' 
    : 'https://localhost:3001',
  IPFS_GATEWAY: 'https://gateway.pinata.cloud/ipfs/',
  SOLANA_RPC: 'https://api.devnet.solana.com'
}

export function createSecureUrl(path: string): string {
  return `${API_CONFIG.BASE_URL}${path}`
}

export function createIPFSUrl(hash: string): string {
  return `${API_CONFIG.IPFS_GATEWAY}${hash}`
}