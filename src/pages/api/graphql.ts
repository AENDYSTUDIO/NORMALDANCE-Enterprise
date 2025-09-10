import { NextApiRequest, NextApiResponse } from 'next'
import { apolloServer, config } from '@/graphql/config'

// Экспорт конфигурации для Next.js
export { config }

// Обработчик запросов GraphQL
export default apolloServer.createHandler({
  path: '/api/graphql',
})