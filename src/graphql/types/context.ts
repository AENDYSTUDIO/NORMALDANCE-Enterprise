import { PrismaClient } from '@prisma/client'

// Интерфейс для контекста GraphQL
export interface GraphQLContext {
  prisma: PrismaClient
  user?: {
    id: string
    email: string
    username: string
    wallet?: string
    isArtist: boolean
    level: string
    role: string
  }
  req: any
  res: any
}

// Интерфейс для пагинации
export interface PaginationInput {
  limit?: number
  offset?: number
}

// Интерфейс для сортировки
export interface SortInput {
  field: string
  direction: 'ASC' | 'DESC'
}

// Интерфейс для фильтрации
export interface FilterInput {
  field: string
  value: any
  operator: 'EQUALS' | 'NOT_EQUALS' | 'CONTAINS' | 'STARTS_WITH' | 'ENDS_WITH' | 'IN' | 'NOT_IN' | 'GREATER_THAN' | 'LESS_THAN' | 'GREATER_THAN_OR_EQUAL' | 'LESS_THAN_OR_EQUAL'
}

// Интерфейс для поиска
export interface SearchInput {
  query: string
  type?: 'ALL' | 'USERS' | 'TRACKS' | 'PLAYLISTS' | 'NFTS'
  limit?: number
  offset?: number
}

// Интерфейс для статистики
export interface StatsInput {
  userId?: string
  timeRange?: '24H' | '7D' | '30D' | 'ALL'
}