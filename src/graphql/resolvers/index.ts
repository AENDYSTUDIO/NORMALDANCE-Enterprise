import { makeExecutableSchema } from '@graphql-tools/schema'
import { mergeResolvers } from '@graphql-tools/merge'
import { loadFilesSync } from '@graphql-tools/load-files'
import { IResolvers } from '@graphql-tools/utils'

// Загрузка всех резолверов
const resolversArray = loadFilesSync(
  `${__dirname}/**/*.resolver.ts`,
  { extensions: ['ts'] }
)

const resolvers = mergeResolvers(resolversArray) as IResolvers

// Загрузка схемы
const typeDefs = loadFilesSync(
  `${__dirname}/../schema/*.graphql`,
  { extensions: ['graphql'] }
)

// Создание исполняемой схемы
export const schema = makeExecutableSchema({
  typeDefs,
  resolvers,
})

export { resolvers }