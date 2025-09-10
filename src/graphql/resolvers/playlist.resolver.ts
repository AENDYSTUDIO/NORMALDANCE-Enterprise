import { GraphQLResolveInfo } from 'graphql'
import { GraphQLContext } from '../types/context'

interface Playlist {
  id: string
  userId: string
  name: string
  description?: string
  coverImage?: string
  playCount: number
  isPublic: boolean
  createdAt: Date
  updatedAt: Date
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

interface PlaylistTrack {
  id: string
  playlistId: string
  trackId: string
  position: number
  addedAt: Date
}

export const playlistResolvers = {
  Query: {
    playlist: async (
      parent: any,
      { id }: { id: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist | null> => {
      const playlist = await prisma.playlist.findUnique({
        where: { id },
        include: {
          user: true,
          tracks: {
            include: {
              track: true
            },
            orderBy: {
              position: 'asc'
            }
          }
        }
      })

      // Проверяем доступ к приватным плейлистам
      if (playlist && !playlist.isPublic && playlist.userId !== user?.id) {
        return null
      }

      return playlist
    },

    playlists: async (
      parent: any,
      { limit = 50, offset = 0, userId, isPublic }: { 
        limit?: number; 
        offset?: number; 
        userId?: string; 
        isPublic?: boolean; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist[]> => {
      const where: any = {}
      
      if (userId) where.userId = userId
      if (isPublic !== undefined) where.isPublic = isPublic

      return prisma.playlist.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: true,
          _count: {
            select: {
              tracks: true
            }
          }
        }
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
          user: true,
          _count: {
            select: {
              tracks: true
            }
          }
        }
      })
    },

    publicPlaylists: async (
      parent: any,
      { limit = 50, offset = 0 }: { limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist[]> => {
      return prisma.playlist.findMany({
        where: { isPublic: true },
        skip: offset,
        take: limit,
        orderBy: { playCount: 'desc' },
        include: {
          user: true,
          _count: {
            select: {
              tracks: true
            }
          }
        }
      })
    },

    trendingPlaylists: async (
      parent: any,
      { limit = 10 }: { limit?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist[]> => {
      return prisma.playlist.findMany({
        where: { isPublic: true },
        take: limit,
        orderBy: [
          { playCount: 'desc' },
          { createdAt: 'desc' }
        ],
        include: {
          user: true,
          _count: {
            select: {
              tracks: true
            }
          }
        }
      })
    },

    recommendedPlaylists: async (
      parent: any,
      { userId, limit = 10 }: { userId: string; limit?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist[]> => {
      if (!userId) {
        return []
      }

      // Получаем плейлисты пользователя для анализа предпочтений
      const userPlaylists = await prisma.playlist.findMany({
        where: { userId },
        include: {
          tracks: {
            include: {
              track: true
            }
          }
        }
      })

      // Собираем жанры из плейлистов пользователя
      const genreCount: Record<string, number> = {}
      userPlaylists.forEach(playlist => {
        playlist.tracks.forEach(playlistTrack => {
          const genre = playlistTrack.track.genre
          if (genre) {
            genreCount[genre] = (genreCount[genre] || 0) + 1
          }
        })
      })

      const topGenres = Object.entries(genreCount)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 3)
        .map(([genre]) => genre)

      // Ищем публичные плейлисты с похожими жанрами
      return prisma.playlist.findMany({
        where: {
          isPublic: true,
          id: { notIn: userPlaylists.map(p => p.id) } // Исключить плейлисты пользователя
        },
        take: limit,
        orderBy: { playCount: 'desc' },
        include: {
          user: true,
          tracks: {
            take: 5, // Только первые 5 треков для предварительного просмотра
            include: {
              track: true
            },
            orderBy: {
              position: 'asc'
            }
          },
          _count: {
            select: {
              tracks: true
            }
          }
        }
      })
    },

    playlistTracks: async (
      parent: any,
      { playlistId, limit = 100, offset = 0 }: { playlistId: string; limit?: number; offset?: number },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<PlaylistTrack[]> => {
      // Проверяем доступ к плейлисту
      const playlist = await prisma.playlist.findUnique({
        where: { id: playlistId }
      })

      if (!playlist) {
        throw new Error('Playlist not found')
      }

      if (!playlist.isPublic && playlist.userId !== user?.id) {
        throw new Error('Access denied')
      }

      return prisma.playlistTrack.findMany({
        where: { playlistId },
        skip: offset,
        take: limit,
        orderBy: { position: 'asc' },
        include: {
          track: true
        }
      })
    },

    isTrackInPlaylist: async (
      parent: any,
      { playlistId, trackId }: { playlistId: string; trackId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      // Проверяем доступ к плейлисту
      const playlist = await prisma.playlist.findUnique({
        where: { id: playlistId }
      })

      if (!playlist) {
        throw new Error('Playlist not found')
      }

      if (!playlist.isPublic && playlist.userId !== user?.id) {
        throw new Error('Access denied')
      }

      const playlistTrack = await prisma.playlistTrack.findUnique({
        where: {
          playlistId_trackId: {
            playlistId,
            trackId
          }
        }
      })

      return !!playlistTrack
    }
  },

  Mutation: {
    createPlaylist: async (
      parent: any,
      { name, description, isPublic = false }: { name: string; description?: string; isPublic?: boolean },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      return prisma.playlist.create({
        data: {
          userId: user.id,
          name,
          description,
          isPublic,
          playCount: 0
        },
        include: {
          user: true,
          tracks: true
        }
      })
    },

    updatePlaylist: async (
      parent: any,
      { id, name, description, coverImage, isPublic }: { 
        id: string; 
        name?: string; 
        description?: string; 
        coverImage?: string; 
        isPublic?: boolean; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем плейлиста
      const existingPlaylist = await prisma.playlist.findUnique({
        where: { id }
      })

      if (!existingPlaylist || existingPlaylist.userId !== user.id) {
        throw new Error('Access denied')
      }

      const updateData: any = {}
      if (name !== undefined) updateData.name = name
      if (description !== undefined) updateData.description = description
      if (coverImage !== undefined) updateData.coverImage = coverImage
      if (isPublic !== undefined) updateData.isPublic = isPublic

      return prisma.playlist.update({
        where: { id },
        data: updateData,
        include: {
          user: true,
          tracks: {
            include: {
              track: true
            },
            orderBy: {
              position: 'asc'
            }
          }
        }
      })
    },

    deletePlaylist: async (
      parent: any,
      { id }: { id: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем плейлиста
      const existingPlaylist = await prisma.playlist.findUnique({
        where: { id }
      })

      if (!existingPlaylist || existingPlaylist.userId !== user.id) {
        throw new Error('Access denied')
      }

      await prisma.playlist.delete({
        where: { id }
      })

      return true
    },

    addTrackToPlaylist: async (
      parent: any,
      { playlistId, trackId }: { playlistId: string; trackId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<PlaylistTrack> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем плейлиста
      const playlist = await prisma.playlist.findUnique({
        where: { id: playlistId }
      })

      if (!playlist || playlist.userId !== user.id) {
        throw new Error('Access denied')
      }

      // Проверяем, что трек еще не добавлен
      const existingTrack = await prisma.playlistTrack.findUnique({
        where: {
          playlistId_trackId: {
            playlistId,
            trackId
          }
        }
      })

      if (existingTrack) {
        throw new Error('Track already in playlist')
      }

      // Получаем следующую позицию
      const lastTrack = await prisma.playlistTrack.findFirst({
        where: { playlistId },
        orderBy: { position: 'desc' }
      })

      const position = lastTrack ? lastTrack.position + 1 : 1

      return prisma.playlistTrack.create({
        data: {
          playlistId,
          trackId,
          position,
          addedAt: new Date()
        },
        include: {
          track: true
        }
      })
    },

    removeTrackFromPlaylist: async (
      parent: any,
      { playlistId, trackId }: { playlistId: string; trackId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<boolean> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем плейлиста
      const playlist = await prisma.playlist.findUnique({
        where: { id: playlistId }
      })

      if (!playlist || playlist.userId !== user.id) {
        throw new Error('Access denied')
      }

      await prisma.playlistTrack.delete({
        where: {
          playlistId_trackId: {
            playlistId,
            trackId
          }
        }
      })

      // Перенумеровываем оставшиеся треки
      const remainingTracks = await prisma.playlistTrack.findMany({
        where: { playlistId },
        orderBy: { position: 'asc' }
      })

      // Обновляем позиции
      for (let i = 0; i < remainingTracks.length; i++) {
        await prisma.playlistTrack.update({
          where: { id: remainingTracks[i].id },
          data: { position: i + 1 }
        })
      }

      return true
    },

    reorderPlaylistTracks: async (
      parent: any,
      { playlistId, trackId, newPosition }: { playlistId: string; trackId: string; newPosition: number },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<PlaylistTrack[]> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем плейлиста
      const playlist = await prisma.playlist.findUnique({
        where: { id: playlistId }
      })

      if (!playlist || playlist.userId !== user.id) {
        throw new Error('Access denied')
      }

      // Получаем все треки в плейлисте
      const tracks = await prisma.playlistTrack.findMany({
        where: { playlistId },
        orderBy: { position: 'asc' }
      })

      // Находим перемещаемый трек
      const trackToMove = tracks.find(t => t.trackId === trackId)
      if (!trackToMove) {
        throw new Error('Track not found in playlist')
      }

      // Удаляем трек из текущей позиции
      const filteredTracks = tracks.filter(t => t.trackId !== trackId)
      
      // Вставляем трек в новую позицию
      const reorderedTracks = [
        ...filteredTracks.slice(0, newPosition - 1),
        trackToMove,
        ...filteredTracks.slice(newPosition - 1)
      ]

      // Обновляем позиции всех треков
      for (let i = 0; i < reorderedTracks.length; i++) {
        await prisma.playlistTrack.update({
          where: { id: reorderedTracks[i].id },
          data: { position: i + 1 }
        })
      }

      return prisma.playlistTrack.findMany({
        where: { playlistId },
        include: {
          track: true
        },
        orderBy: { position: 'asc' }
      })
    },

    incrementPlaylistPlayCount: async (
      parent: any,
      { playlistId }: { playlistId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Playlist> => {
      return prisma.playlist.update({
        where: { id: playlistId },
        data: { playCount: { increment: 1 } },
        include: {
          user: true,
          tracks: {
            include: {
              track: true
            },
            orderBy: {
              position: 'asc'
            }
          }
        }
      })
    }
  },

  Playlist: {
    user: (parent: Playlist, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<User> => {
      return prisma.user.findUnique({
        where: { id: parent.userId }
      })
    },

    tracks: (parent: Playlist, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<PlaylistTrack[]> => {
      return prisma.playlistTrack.findMany({
        where: { playlistId: parent.id },
        include: {
          track: true
        },
        orderBy: {
          position: 'asc'
        }
      })
    },

    trackCount: (parent: Playlist, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<number> => {
      return prisma.playlistTrack.count({
        where: { playlistId: parent.id }
      })
    },

    duration: async (parent: Playlist, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<number> => {
      const tracks = await prisma.playlistTrack.findMany({
        where: { playlistId: parent.id },
        include: {
          track: true
        }
      })

      return tracks.reduce((sum, playlistTrack) => sum + (playlistTrack.track.duration || 0), 0)
    },

    isOwnedByUser: async (parent: Playlist, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      return parent.userId === user.id
    },

    canBeEdited: async (parent: Playlist, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      return parent.userId === user.id
    }
  },

  PlaylistTrack: {
    playlist: (parent: PlaylistTrack, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Playlist> => {
      return prisma.playlist.findUnique({
        where: { id: parent.playlistId }
      })
    },

    track: (parent: PlaylistTrack, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Track> => {
      return prisma.track.findUnique({
        where: { id: parent.trackId }
      })
    }
  }
}