import { ApolloServer, gql } from 'apollo-server-micro'
import { NextApiRequest, NextApiResponse } from 'next'
import { createContext } from './types/context'
import { resolvers } from './resolvers'
import { typeDefs } from './schema'

// Создаем Apollo Server
const apolloServer = new ApolloServer({
  typeDefs,
  resolvers,
  context: ({ req, res }) => createContext({ req, res }),
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

export const config = {
  api: {
    bodyParser: false,
  },
}

export default apolloServer.createHandler({
  path: '/api/graphql',
})