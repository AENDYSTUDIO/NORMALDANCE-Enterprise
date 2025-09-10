import { GraphQLContext } from './types/context'
import { NextApiRequest } from 'next'
import { getToken } from 'next-auth/jwt'

/**
 * Функция для получения пользователя из контекста GraphQL
 * Интегрируется с существующей системой аутентификации NextAuth.js
 */
export async function getUserFromContext(context: GraphQLContext): Promise<any> {
  try {
    const { req } = context
    
    // Получаем токен из запроса
    const token = await getToken({ req })
    
    if (token && token.sub) {
      // Возвращаем информацию о пользователе
      return {
        id: token.sub,
        email: token.email,
        name: token.name,
        image: token.picture,
        // Добавляем любые другие поля, которые могут быть в токене
        ...token
      }
    }
    
    return null
  } catch (error) {
    console.error('Error getting user from context:', error)
    return null
  }
}

/**
 * Middleware для проверки аутентификации
 */
export function requireAuth(context: GraphQLContext): Promise<any> {
  return getUserFromContext(context)
}

/**
 * Middleware для проверки ролей пользователя
 */
export function requireRole(context: GraphQLContext, roles: string[]): Promise<any> {
  return getUserFromContext(context).then(user => {
    if (!user) {
      throw new Error('Authentication required')
    }
    
    if (!roles.includes(user.role)) {
      throw new Error(`Insufficient permissions. Required: ${roles.join(', ')}`)
    }
    
    return user
  })
}

/**
 * Middleware для проверки, является ли пользователь артистом
 */
export function requireArtist(context: GraphQLContext): Promise<any> {
  return requireRole(context, ['ARTIST', 'ADMIN'])
}

/**
 * Middleware для проверки, является ли пользователь куратором
 */
export function requireCurator(context: GraphQLContext): Promise<any> {
  return requireRole(context, ['CURATOR', 'ADMIN'])
}

/**
 * Middleware для проверки, является ли пользователь администратором
 */
export function requireAdmin(context: GraphQLContext): Promise<any> {
  return requireRole(context, ['ADMIN'])
}

/**
 * Функция для проверки прав доступа к ресурсу
 */
export function checkResourceAccess(
  context: GraphQLContext, 
  resourceOwnerId: string, 
  requiredRole?: string
): Promise<boolean> {
  return getUserFromContext(context).then(user => {
    if (!user) {
      return false
    }
    
    // Если пользователь администратор, имеет доступ ко всем ресурсам
    if (user.role === 'ADMIN') {
      return true
    }
    
    // Если требуется определенная роль
    if (requiredRole && user.role !== requiredRole) {
      return false
    }
    
    // Проверяем, является ли пользователь владельцем ресурса
    return user.id === resourceOwnerId
  })
}

/**
 * Функция для подписи транзакций через кошелек пользователя
 */
export async function signTransactionWithWallet(
  context: GraphQLContext, 
  transaction: any
): Promise<any> {
  const user = await getUserFromContext(context)
  
  if (!user || !user.wallet) {
    throw new Error('Wallet not connected')
  }
  
  // Здесь должна быть логика подписи транзакции через кошелек пользователя
  // Например, через Phantom или другой Solana кошелек
  
  try {
    // TODO: Реализовать подпись транзакции
    // const signedTransaction = await wallet.signTransaction(transaction)
    // return signedTransaction
    
    return transaction // Временное возвращение для тестирования
  } catch (error) {
    console.error('Error signing transaction:', error)
    throw new Error('Failed to sign transaction')
  }
}

/**
 * Функция для проверки баланса пользователя
 */
export async function checkUserBalance(
  context: GraphQLContext, 
  amount: number, 
  currency: 'SOL' | 'TOKEN' = 'SOL'
): Promise<boolean> {
  const user = await getUserFromContext(context)
  
  if (!user || !user.wallet) {
    return false
  }
  
  // Валидация входных данных
  if (amount < 0 || !Number.isFinite(amount)) {
    throw new Error('Invalid amount')
  }
  
  // Санитизация wallet адреса
  const sanitizedWallet = user.wallet.replace(/[^a-zA-Z0-9]/g, '')
  if (sanitizedWallet.length < 32) {
    throw new Error('Invalid wallet address')
  }
  
  try {
    // Используем параметризованный запрос
    const query = currency === 'SOL' 
      ? 'query CheckSOLBalance($address: String!) { walletBalance(address: $address) }'
      : 'query CheckTokenBalance($address: String!, $mint: String!) { tokenBalance(walletAddress: $address, mintAddress: $mint) }'
    
    const variables = currency === 'SOL' 
      ? { address: sanitizedWallet }
      : { address: sanitizedWallet, mint: process.env.TOKEN_MINT_ADDRESS }
    
    const response = await fetch('/api/graphql', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${context.req.headers.authorization?.replace(/[^a-zA-Z0-9.-]/g, '')}`
      },
      body: JSON.stringify({ query, variables })
    })
    
    if (!response.ok) {
      throw new Error('Network error')
    }
    
    const data = await response.json()
    
    if (data.errors) {
      throw new Error('GraphQL error')
    }
    
    const balance = currency === 'SOL' ? data.data?.walletBalance : data.data?.tokenBalance
    return typeof balance === 'number' && balance >= amount
  } catch (error) {
    // Безопасное логирование без пользовательских данных
    console.error('Balance check failed:', { currency, timestamp: Date.now() })
    return false
  }
}

/**
 * Функция для создания подписанного сообщения для верификации
 */
export async function createSignedMessage(
  context: GraphQLContext, 
  message: string
): Promise<string> {
  const user = await getUserFromContext(context)
  
  if (!user || !user.wallet) {
    throw new Error('Wallet not connected')
  }
  
  // Валидация и санитизация сообщения
  if (!message || typeof message !== 'string') {
    throw new Error('Invalid message')
  }
  
  const sanitizedMessage = message.replace(/[<>"'&]/g, '').slice(0, 1000)
  
  try {
    // TODO: Реализовать создание подписанного сообщения
    // const signedMessage = await wallet.signMessage(sanitizedMessage)
    // return signedMessage
    
    return sanitizedMessage // Временное возвращение для тестирования
  } catch (error) {
    // Безопасное логирование
    console.error('Message signing failed:', { timestamp: Date.now() })
    throw new Error('Failed to create signed message')
  }
}