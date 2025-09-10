import { GraphQLResolveInfo } from 'graphql'
import { GraphQLContext } from '../types/context'

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
  artistId: string
}

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

interface Like {
  id: string
  userId: string
  trackId: string
  createdAt: Date
}

interface Comment {
  id: string
  content: string
  userId: string
  trackId: string
  createdAt: Date
  updatedAt: Date
}

interface PlaylistTrack {
  id: string
  playlistId: string
  trackId: string
  position: number
  addedAt: Date
}

interface PlayHistory {
  id: string
  userId: string
  trackId: string
  duration: number
  completed: boolean
  createdAt: Date
}

interface NFT {
  id: string
  tokenId: string
  name: string
  description?: string
  imageUrl?: string
  metadata?: any
  price?: number
  status: string
  type: string
  createdAt: Date
  updatedAt: Date
  trackId?: string
  ownerId: string
}

export const trackResolvers = {
  Query: {
    track: async (
      parent: any,
      { id }: { id: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track | null> => {
      return prisma.track.findUnique({
        where: { id },
        include: {
          artist: true,
          likes: true,
          comments: true,
          playlistTracks: true,
          playHistory: true,
          nfts: true
        }
      })
    },

    tracks: async (
      parent: any,
      { limit = 50, offset = 0, genre, artistId }: { limit?: number; offset?: number; genre?: string; artistId?: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track[]> => {
      const where: any = {}
      
      if (genre) where.genre = genre
      if (artistId) where.artistId = artistId

      return prisma.track.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          artist: true,
          _count: {
            select: {
              likes: true,
              comments: true,
              playHistory: true
            }
          }
        }
      })
    },

    tracksByUser: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track[]> => {
      return prisma.track.findMany({
        where: { artistId: userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          artist: true,
          _count: {
            select: {
              likes: true,
              comments: true,
              playHistory: true
            }
          }
        }
      })
    },

    trendingTracks: async (
      parent: any,
      { limit = 10 }: { limit?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track[]> => {
      // Трендовые треки - те, у которых много воспроизведений за последние 7 дней
      const sevenDaysAgo = new Date()
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)

      return prisma.track.findMany({
        take: limit,
        orderBy: [
          { playCount: 'desc' },
          { createdAt: 'desc' }
        ],
        include: {
          artist: true,
          _count: {
            select: {
              likes: true,
              comments: true
            }
          }
        }
      })
    },

    recommendedTracks: async (
      parent: any,
      { userId, limit = 10 }: { userId: string; limit?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track[]> => {
      // Простая рекомендация: треки из жанров, которые пользователь слушает чаще всего
      const userPlayHistory = await prisma.playHistory.findMany({
        where: { userId },
        include: {
          track: true
        },
        orderBy: { createdAt: 'desc' },
        take: 50
      })

      const genreCount: Record<string, number> = {}
      userPlayHistory.forEach(play => {
        if (play.track.genre) {
          genreCount[play.track.genre] = (genreCount[play.track.genre] || 0) + 1
        }
      })

      const topGenres = Object.entries(genreCount)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 3)
        .map(([genre]) => genre)

      return prisma.track.findMany({
        where: {
          genre: { in: topGenres },
          id: { notIn: userPlayHistory.map(play => play.trackId) } // Исключить уже прослушанные
        },
        take: limit,
        orderBy: { playCount: 'desc' },
        include: {
          artist: true,
          _count: {
            select: {
              likes: true,
              comments: true
            }
          }
        }
      })
    },

    comments: async (
      parent: any,
      { trackId, limit = 50, offset = 0 }: { trackId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Comment[]> => {
      return prisma.comment.findMany({
        where: { trackId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: true
        }
      })
    },

    trackLikes: async (
      parent: any,
      { trackId, limit = 50, offset = 0 }: { trackId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Like[]> => {
      return prisma.like.findMany({
        where: { trackId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: true
        }
      })
    },

    trackPlayHistory: async (
      parent: any,
      { trackId, limit = 50, offset = 0 }: { trackId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<PlayHistory[]> => {
      return prisma.playHistory.findMany({
        where: { trackId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: true
        }
      })
    }
  },

  Mutation: {
    createTrack: async (
      parent: any,
      { title, artistName, genre, duration, ipfsHash, metadata, price, isExplicit, coverImage }: any,
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Генерация URL для аудио (в реальном проекте это бы делалось через IPFS/Filecoin)
      const audioUrl = `https://ipfs.io/ipfs/${ipfsHash}`

      return prisma.track.create({
        data: {
          title,
          artistName,
          genre,
          duration,
          ipfsHash,
          metadata,
          price,
          isExplicit: isExplicit || false,
          isPublished: true,
          audioUrl,
          coverImage,
          artistId: user.id
        },
        include: {
          artist: true,
          _count: {
            select: {
              likes: true,
              comments: true,
              playHistory: true
            }
          }
        }
      })
    },

    updateTrack: async (
      parent: any,
      { id, title, artistName, genre, price, isExplicit, isPublished, coverImage }: any,
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Track> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем трека
      const existingTrack = await prisma.track.findUnique({
        where: { id }
      })

      if (!existingTrack || existingTrack.artistId !== user.id) {
        throw new Error('Access denied')
      }

      const updateData: any = {}
      if (title !== undefined) updateData.title = title
      if (artistName !== undefined) updateData.artistName = artistName
      if (genre !== undefined) updateData.genre = genre
      if (price !== undefined) updateData.price = price
      if (isExplicit !== undefined) updateData.isExplicit = isExplicit
      if (isPublished !== undefined) updateData.isPublished = isPublished
      if (coverImage !== undefined) updateData.coverImage = coverImage

      return prisma.track.update({
        where: { id },
        data: updateData,
        include: {
          artist: true,
          _count: {
            select: {
              likes: true,
              comments: true,
              playHistory: true
            }
          }
        }
      })
    },

    deleteTrack: async (
      parent: any,
      { id }: { id: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем трека
      const existingTrack = await prisma.track.findUnique({
        where: { id }
      })

      if (!existingTrack || existingTrack.artistId !== user.id) {
        throw new Error('Access denied')
      }

      await prisma.track.delete({
        where: { id }
      })

      return true
    },

    likeTrack: async (
      parent: any,
      { trackId }: { trackId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Like> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, не лайкал ли пользователь уже этот трек
      const existingLike = await prisma.like.findUnique({
        where: {
          userId_trackId: {
            userId: user.id,
            trackId
          }
        }
      })

      if (existingLike) {
        throw new Error('Track already liked')
      }

      return prisma.like.create({
        data: {
          userId: user.id,
          trackId
        },
        include: {
          user: true,
          track: true
        }
      })
    },

    unlikeTrack: async (
      parent: any,
      { trackId }: { trackId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      await prisma.like.delete({
        where: {
          userId_trackId: {
            userId: user.id,
            trackId
          }
        }
      })

      return true
    },

    createComment: async (
      parent: any,
      { trackId, content }: { trackId: string; content: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Comment> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      return prisma.comment.create({
        data: {
          userId: user.id,
          trackId,
          content
        },
        include: {
          user: true,
          track: true
        }
      })
    },

    updateComment: async (
      parent: any,
      { id, content }: { id: string; content: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Comment> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является автором комментария
      const existingComment = await prisma.comment.findUnique({
        where: { id }
      })

      if (!existingComment || existingComment.userId !== user.id) {
        throw new Error('Access denied')
      }

      return prisma.comment.update({
        where: { id },
        data: { content },
        include: {
          user: true,
          track: true
        }
      })
    },

    deleteComment: async (
      parent: any,
      { id }: { id: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является автором комментария
      const existingComment = await prisma.comment.findUnique({
        where: { id }
      })

      if (!existingComment || existingComment.userId !== user.id) {
        throw new Error('Access denied')
      }

      await prisma.comment.delete({
        where: { id }
      })

      return true
    },

    recordPlayHistory: async (
      parent: any,
      { trackId, duration, completed = false }: { trackId: string; duration: number; completed?: boolean },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<PlayHistory> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Увеличиваем счетчик воспроизведений трека
      await prisma.track.update({
        where: { id: trackId },
        data: { playCount: { increment: 1 } }
      })

      return prisma.playHistory.create({
        data: {
          userId: user.id,
          trackId,
          duration,
          completed
        },
        include: {
          user: true,
          track: true
        }
      })
    }
  },

  Track: {
    artist: (parent: Track, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<User> => {
      return prisma.user.findUnique({
        where: { id: parent.artistId }
      })
    },

    likes: (parent: Track, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Like[]> => {
      return prisma.like.findMany({
        where: { trackId: parent.id },
        include: {
          user: true
        }
      })
    },

    comments: (parent: Track, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Comment[]> => {
      return prisma.comment.findMany({
        where: { trackId: parent.id },
        include: {
          user: true
        }
      })
    },

    playlistTracks: (parent: Track, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<PlaylistTrack[]> => {
      return prisma.playlistTrack.findMany({
        where: { trackId: parent.id },
        include: {
          playlist: true
        }
      })
    },

    playHistory: (parent: Track, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<PlayHistory[]> => {
      return prisma.playHistory.findMany({
        where: { trackId: parent.id },
        include: {
          user: true
        }
      })
    },

    nfts: (parent: Track, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<NFT[]> => {
      return prisma.nFT.findMany({
        where: { trackId: parent.id },
        include: {
          owner: true
        }
      })
    },

    isLiked: async (parent: Track, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      
      const like = await prisma.like.findUnique({
        where: {
          userId_trackId: {
            userId: user.id,
            trackId: parent.id
          }
        }
      })
      return !!like
    },

    isSaved: async (parent: Track, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      
      // В реальном проекте здесь была бы проверка на сохранение в плейлисты
      return false
    }
  }
}