import { ApolloServer } from 'apollo-server-micro'
import { NextApiRequest, NextApiResponse } from 'next'
import { makeExecutableSchema } from '@graphql-tools/schema'
import { loadFilesSync } from '@graphql-tools/load-files'
import { mergeResolvers } from '@graphql-tools/merge'
import { IResolvers } from '@graphql-tools/utils'

// Загрузка всех резолверов
const resolversArray = loadFilesSync(
  `${__dirname}/resolvers/**/*.resolver.ts`,
  { extensions: ['ts'] }
)

const resolvers = mergeResolvers(resolversArray) as IResolvers

// Загрузка схемы
const typeDefs = loadFilesSync(
  `${__dirname}/schema/*.graphql`,
  { extensions: ['graphql'] }
)

// Создание исполняемой схемы
export const schema = makeExecutableSchema({
  typeDefs,
  resolvers,
})

// Создание Apollo Server
export const apolloServer = new ApolloServer({
  schema,
  context: ({ req, res }) => ({
    req,
    res,
    // Добавляем Prisma клиент из глобальной инстанции
    prisma: globalThis.prisma,
    // Добавляем пользователя из сессии
    user: req.user || null,
  }),
  introspection: true,
  playground: true,
  plugins: [
    {
      requestDidStart(requestContext) {
        console.log(`GraphQL Request: ${requestContext.operation?.operation} ${requestContext.operation?.name}`)
        return {
          willSendResponse(requestContext) {
            const response = requestContext.response
            console.log(`GraphQL Response: ${response.http.status}`)
          }
        }
      }
    }
  ]
})

// Конфигурация Next.js API route
export const config = {
  api: {
    bodyParser: false,
  },
}

// Экспорт обработчика
export default apolloServer.createHandler({
  path: '/api/graphql',
})