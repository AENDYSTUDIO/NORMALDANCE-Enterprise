import { GraphQLResolveInfo } from 'graphql'
import { GraphQLContext } from '../types/context'
import { PrismaClient } from '@prisma/client'

interface User {
  id: string
  email: string
  username: string
  displayName?: string
  bio?: string
  avatar?: string
  banner?: string
  wallet?: string
  level: string
  balance: number
  isArtist: boolean
  role: string
  isActive: boolean
  createdAt: Date
  updatedAt: Date
}

interface Track {
  id: string
  title: string
  artistName: string
  genre: string
  duration: number
  playCount: number
  likeCount: number
  ipfsHash: string
  metadata?: any
  price?: number
  isExplicit: boolean
  isPublished: boolean
  createdAt: Date
  updatedAt: Date
  audioUrl: string
  coverImage?: string
}

interface Playlist {
  id: string
  name: string
  description?: string
  isPublic: boolean
  coverImage?: string
  playCount: number
  createdAt: Date
  updatedAt: Date
}

export const userResolvers = {
  Query: {
    user: async (
      parent: any,
      { id }: { id: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User | null> => {
      return prisma.user.findUnique({
        where: { id },
        include: {
          _count: {
            select: {
              tracks: true,
              playlists: true,
              followers: true,
              following: true,
              likes: true,
              comments: true,
              rewards: true,
            }
          },
          tracks: {
            take: 6,
            orderBy: { createdAt: 'desc' }
          },
          followers: true,
          following: true,
          likes: true,
          comments: true,
          rewards: true,
          playHistory: {
            take: 10,
            orderBy: { createdAt: 'desc' }
          },
          nfts: true,
          purchases: true,
          stakes: true
        }
      })
    },

    currentUser: async (
      parent: any,
      args: any,
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User | null> => {
      if (!user) return null
      return userResolvers.Query.user(parent, { id: user.id }, { prisma, user }, info)
    },

    users: async (
      parent: any,
      { limit = 50, offset = 0 }: { limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User[]> => {
      return prisma.user.findMany({
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          _count: {
            select: {
              tracks: true,
              playlists: true,
              followers: true,
              following: true,
            }
          }
        }
      })
    },

    userByUsername: async (
      parent: any,
      { username }: { username: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User | null> => {
      return prisma.user.findUnique({
        where: { username },
        include: {
          _count: {
            select: {
              tracks: true,
              playlists: true,
              followers: true,
              following: true,
            }
          }
        }
      })
    },

    userByWallet: async (
      parent: any,
      { wallet }: { wallet: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User | null> => {
      return prisma.user.findUnique({
        where: { wallet },
        include: {
          _count: {
            select: {
              tracks: true,
              playlists: true,
              followers: true,
              following: true,
            }
          }
        }
      })
    },

    userTracks: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track[]> => {
      return prisma.track.findMany({
        where: { artistId: userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' }
      })
    },

    userPlaylists: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist[]> => {
      return prisma.playlist.findMany({
        where: { userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          _count: {
            select: { tracks: true }
          }
        }
      })
    },

    userLikes: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      return prisma.like.findMany({
        where: { userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          track: true
        }
      })
    },

    userRewards: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      return prisma.reward.findMany({
        where: { userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' }
      })
    },

    userFollowers: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User[]> => {
      const follows = await prisma.follow.findMany({
        where: { followingId: userId },
        skip: offset,
        take: limit,
        include: {
          follower: true
        }
      })
      return follows.map(f => f.follower)
    },

    userFollowing: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User[]> => {
      const follows = await prisma.follow.findMany({
        where: { followerId: userId },
        skip: offset,
        take: limit,
        include: {
          following: true
        }
      })
      return follows.map(f => f.following)
    },

    userNFTs: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      return prisma.nFT.findMany({
        where: { ownerId: userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          track: true,
          owner: true
        }
      })
    },

    userPurchases: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      return prisma.purchase.findMany({
        where: { buyerId: userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          nft: {
            include: {
              track: true,
              owner: true
            }
          }
        }
      })
    },

    userStakes: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      return prisma.stake.findMany({
        where: { userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          token: true
        }
      })
    },

    userPlayHistory: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      return prisma.playHistory.findMany({
        where: { userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          track: true
        }
      })
    },

    isFollowing: async (
      parent: any,
      { followerId, followingId }: { followerId: string; followingId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId,
            followingId
          }
        }
      })
      return !!follow
    }
  },

  Mutation: {
    updateUserProfile: async (
      parent: any,
      { displayName, bio, avatar, banner, wallet, isArtist }: any,
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      const updateData: any = {}
      if (displayName !== undefined) updateData.displayName = displayName
      if (bio !== undefined) updateData.bio = bio
      if (avatar !== undefined) updateData.avatar = avatar
      if (banner !== undefined) updateData.banner = banner
      if (wallet !== undefined) updateData.wallet = wallet
      if (isArtist !== undefined) updateData.isArtist = isArtist

      return prisma.user.update({
        where: { id: user.id },
        data: updateData,
        include: {
          _count: {
            select: {
              tracks: true,
              playlists: true,
              followers: true,
              following: true,
            }
          }
        }
      })
    },

    updateUserLevel: async (
      parent: any,
      { level }: { level: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<User> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      return prisma.user.update({
        where: { id: user.id },
        data: { level },
        include: {
          _count: {
            select: {
              tracks: true,
              playlists: true,
              followers: true,
              following: true,
            }
          }
        }
      })
    }
  },

  User: {
    // Field resolvers for User type
    tracks: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.track.findMany({
        where: { artistId: parent.id },
        take: 6,
        orderBy: { createdAt: 'desc' }
      })
    },

    playlists: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.playlist.findMany({
        where: { userId: parent.id },
        take: 6,
        orderBy: { createdAt: 'desc' }
      })
    },

    followers: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.follow.findMany({
        where: { followingId: parent.id },
        include: {
          follower: true
        }
      }).then(follows => follows.map(f => f.follower))
    },

    following: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.follow.findMany({
        where: { followerId: parent.id },
        include: {
          following: true
        }
      }).then(follows => follows.map(f => f.following))
    },

    trackCount: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.track.count({
        where: { artistId: parent.id }
      })
    },

    playlistCount: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.playlist.count({
        where: { userId: parent.id }
      })
    },

    followerCount: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.follow.count({
        where: { followingId: parent.id }
      })
    },

    followingCount: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.follow.count({
        where: { followerId: parent.id }
      })
    },

    likeCount: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.like.count({
        where: { userId: parent.id }
      })
    },

    commentCount: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.comment.count({
        where: { userId: parent.id }
      })
    },

    totalEarnings: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.reward.aggregate({
        where: { userId: parent.id },
        _sum: { amount: true }
      }).then(result => result._sum.amount || 0)
    },

    totalPlays: (parent: User, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo) => {
      return prisma.playHistory.count({
        where: { userId: parent.id }
      })
    }
  }
}