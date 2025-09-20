import { db } from '../db';

export const resolvers = {
  Query: {
    tracks: async () => {
      return await db.track.findMany({
        include: { user: true }
      });
    },
    
    track: async (_: any, { id }: { id: string }) => {
      return await db.track.findUnique({
        where: { id },
        include: { user: true }
      });
    },
    
    nfts: async () => {
      return await db.nFT.findMany({
        include: { owner: true, track: true }
      });
    }
  },

  Mutation: {
    createTrack: async (_: any, { title, artist, ipfsHash }: any) => {
      return await db.track.create({
        data: { title, artist, ipfsHash, userId: 'temp-user-id' }
      });
    },
    
    mintNFT: async (_: any, { trackId, name }: any) => {
      return await db.nFT.create({
        data: {
          tokenId: `nft-${Date.now()}`,
          name,
          ownerId: 'temp-user-id',
          trackId
        }
      });
    }
  }
};