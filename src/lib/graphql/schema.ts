export const typeDefs = `
  type User {
    id: ID!
    username: String!
    walletAddress: String
    tracks: [Track!]!
  }

  type Track {
    id: ID!
    title: String!
    artist: String!
    ipfsHash: String!
    playCount: Int!
    price: Float
  }

  type NFT {
    id: ID!
    tokenId: String!
    name: String!
    price: Float
    track: Track
  }

  type Query {
    tracks: [Track!]!
    track(id: ID!): Track
    nfts: [NFT!]!
  }

  type Mutation {
    createTrack(title: String!, artist: String!, ipfsHash: String!): Track!
    mintNFT(trackId: ID!, name: String!): NFT!
  }
`;