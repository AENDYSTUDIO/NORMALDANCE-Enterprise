import { GraphQLResolveInfo } from 'graphql'
import { GraphQLContext } from '../types/context'

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

interface Purchase {
  id: string
  nftId: string
  buyerId: string
  sellerId: string
  price: number
  transactionHash?: string
  status: string
  createdAt: Date
  updatedAt: Date
}

interface Stake {
  id: string
  userId: string
  tokenId: string
  amount: number
  apy: number
  startDate: Date
  endDate?: Date
  status: string
  rewards: number
  createdAt: Date
  updatedAt: Date
}

interface Transaction {
  id: string
  hash: string
  type: string
  amount: number
  currency: string
  fromAddress: string
  toAddress: string
  status: string
  blockNumber: number
  gasUsed: number
  gasPrice: number
  timestamp: Date
  metadata?: any
}

interface Token {
  id: string
  symbol: string
  name: string
  decimals: number
  totalSupply: number
  price: number
  marketCap: number
  volume24h: number
  imageUrl?: string
  description?: string
  website?: string
  isVerified: boolean
  createdAt: Date
  updatedAt: Date
}

// Mock Web3 сервис для демонстрации
class Web3Service {
  async mintNFT(
    wallet: string,
    trackId: string,
    name: string,
    description: string,
    imageUrl: string,
    metadata: any
  ): Promise<{ transactionHash: string; tokenId: string }> {
    // В реальном проекте здесь была бы интеграция с Solana и Anchor программой
    // Для демонстрации возвращаем моковые данные
    return {
      transactionHash: '0x1234567890abcdef1234567890abcdef12345678',
      tokenId: `nft_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    }
  }

  async transferNFT(
    fromWallet: string,
    toWallet: string,
    tokenId: string
  ): Promise<{ transactionHash: string }> {
    // В реальном проекте здесь была бы интеграция с Solana
    return {
      transactionHash: '0xabcdef1234567890abcdef1234567890abcdef'
    }
  }

  async createStake(
    wallet: string,
    tokenId: string,
    amount: number
  ): Promise<{ transactionHash: string; stakeId: string }> {
    // В реальном проекте здесь была бы интеграция с Solana
    return {
      transactionHash: '0x9876543210fedcba9876543210fedcba98765432',
      stakeId: `stake_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    }
  }

  async unstake(
    wallet: string,
    stakeId: string
  ): Promise<{ transactionHash: string }> {
    // В реальном проекте здесь была бы интеграция с Solana
    return {
      transactionHash: '0x1111222233334444555566667777888899990000'
    }
  }

  async getNFTMetadata(tokenId: string): Promise<any> {
    // В реальном проекте здесь был бы запрос к метаданным NFT
    return {
      tokenId,
      name: `NFT ${tokenId}`,
      description: 'Music NFT',
      image: 'https://example.com/image.jpg',
      attributes: [
        { trait_type: 'Artist', value: 'Unknown' },
        { trait_type: 'Genre', value: 'Electronic' },
        { trait_type: 'Duration', value: '180' }
      ]
    }
  }
}

const web3Service = new Web3Service()

export const nftResolvers = {
  Query: {
    nft: async (
      parent: any,
      { id }: { id: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT | null> => {
      return prisma.nFT.findUnique({
        where: { id },
        include: {
          track: true,
          owner: true,
          purchases: true,
          stakes: true
        }
      })
    },

    nftByTokenId: async (
      parent: any,
      { tokenId }: { tokenId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT | null> => {
      return prisma.nFT.findUnique({
        where: { tokenId },
        include: {
          track: true,
          owner: true,
          purchases: true,
          stakes: true
        }
      })
    },

    nfts: async (
      parent: any,
      { limit = 50, offset = 0, trackId, ownerId, status, type }: { 
        limit?: number; 
        offset?: number; 
        trackId?: string; 
        ownerId?: string; 
        status?: string; 
        type?: string; 
      },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT[]> => {
      const where: any = {}
      
      if (trackId) where.trackId = trackId
      if (ownerId) where.ownerId = ownerId
      if (status) where.status = status
      if (type) where.type = type

      return prisma.nFT.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          track: true,
          owner: true,
          _count: {
            select: {
              purchases: true,
              stakes: true
            }
          }
        }
      })
    },

    userNFTs: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT[]> => {
      return prisma.nFT.findMany({
        where: { ownerId: userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          track: true,
          owner: true,
          _count: {
            select: {
              purchases: true,
              stakes: true
            }
          }
        }
      })
    },

    trackNFTs: async (
      parent: any,
      { trackId, limit = 50, offset = 0 }: { trackId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT[]> => {
      return prisma.nFT.findMany({
        where: { trackId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          track: true,
          owner: true,
          _count: {
            select: {
              purchases: true,
              stakes: true
            }
          }
        }
      })
    },

    purchases: async (
      parent: any,
      { limit = 50, offset = 0, nftId, buyerId, sellerId }: { 
        limit?: number; 
        offset?: number; 
        nftId?: string; 
        buyerId?: string; 
        sellerId?: string; 
      },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Purchase[]> => {
      const where: any = {}
      
      if (nftId) where.nftId = nftId
      if (buyerId) where.buyerId = buyerId
      if (sellerId) where.sellerId = sellerId

      return prisma.purchase.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          nft: {
            include: {
              track: true,
              owner: true
            }
          },
          buyer: true,
          seller: true
        }
      })
    },

    stakes: async (
      parent: any,
      { limit = 50, offset = 0, userId, tokenId, status }: { 
        limit?: number; 
        offset?: number; 
        userId?: string; 
        tokenId?: string; 
        status?: string; 
      },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Stake[]> => {
      const where: any = {}
      
      if (userId) where.userId = userId
      if (tokenId) where.tokenId = tokenId
      if (status) where.status = status

      return prisma.stake.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          token: true,
          user: true
        }
      })
    },

    userStakes: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Stake[]> => {
      return prisma.stake.findMany({
        where: { userId },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          token: true,
          user: true
        }
      })
    },

    nftTransactions: async (
      parent: any,
      { nftId, limit = 50, offset = 0 }: { nftId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Transaction[]> => {
      // В реальном проекте здесь был бы запрос к блокчейну
      // Для демонстрации возвращаем моковые данные
      return []
    },

    nftStats: async (
      parent: any,
      { nftId }: { nftId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      const nft = await prisma.nFT.findUnique({
        where: { id: nftId },
        include: {
          purchases: true,
          stakes: true
        }
      })

      if (!nft) {
        throw new Error('NFT not found')
      }

      const totalPurchases = nft.purchases.length
      const totalStakes = nft.stakes.length
      const totalVolume = nft.purchases.reduce((sum, purchase) => sum + purchase.price, 0)
      const averagePrice = totalPurchases > 0 ? totalVolume / totalPurchases : 0

      return {
        nftId,
        totalPurchases,
        totalStakes,
        totalVolume,
        averagePrice,
        currentPrice: nft.price
      }
    },

    nftMetadata: async (
      parent: any,
      { tokenId }: { tokenId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      return web3Service.getNFTMetadata(tokenId)
    }
  },

  Mutation: {
    mintNFT: async (
      parent: any,
      { 
        trackId, 
        name, 
        description, 
        imageUrl, 
        metadata, 
        price 
      }: { 
        trackId: string; 
        name: string; 
        description?: string; 
        imageUrl?: string; 
        metadata?: any; 
        price?: number; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что трек существует и пользователь является его владельцем
      const track = await prisma.track.findUnique({
        where: { id: trackId }
      })

      if (!track) {
        throw new Error('Track not found')
      }

      // В реальном проекте здесь была бы проверка прав собственности на трек
      // Для демонстрации пропускаем эту проверку

      // Минтинг NFT через Web3 сервис
      const mintResult = await web3Service.mintNFT(
        user.wallet || '',
        trackId,
        name,
        description || '',
        imageUrl || '',
        metadata || {}
      )

      // Создаем запись в базе данных
      return prisma.nFT.create({
        data: {
          tokenId: mintResult.tokenId,
          name,
          description,
          imageUrl,
          metadata,
          price,
          status: 'LISTED',
          type: 'MUSIC',
          trackId,
          ownerId: user.id
        },
        include: {
          track: true,
          owner: true
        }
      })
    },

    updateNFT: async (
      parent: any,
      { id, name, description, imageUrl, price, status }: { 
        id: string; 
        name?: string; 
        description?: string; 
        imageUrl?: string; 
        price?: number; 
        status?: string; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем NFT
      const existingNFT = await prisma.nFT.findUnique({
        where: { id }
      })

      if (!existingNFT || existingNFT.ownerId !== user.id) {
        throw new Error('Access denied')
      }

      const updateData: any = {}
      if (name !== undefined) updateData.name = name
      if (description !== undefined) updateData.description = description
      if (imageUrl !== undefined) updateData.imageUrl = imageUrl
      if (price !== undefined) updateData.price = price
      if (status !== undefined) updateData.status = status

      return prisma.nFT.update({
        where: { id },
        data: updateData,
        include: {
          track: true,
          owner: true
        }
      })
    },

    transferNFT: async (
      parent: any,
      { nftId, toWallet }: { nftId: string; toWallet: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<{ transactionHash: string }> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем NFT
      const nft = await prisma.nFT.findUnique({
        where: { id: nftId }
      })

      if (!nft || nft.ownerId !== user.id) {
        throw new Error('Access denied')
      }

      // Трансфер NFT через Web3 сервис
      const transferResult = await web3Service.transferNFT(
        user.wallet || '',
        toWallet,
        nft.tokenId
      )

      // Обновляем владельца NFT
      await prisma.nFT.update({
        where: { id: nftId },
        data: { ownerId: toWallet }
      })

      return transferResult
    },

    purchaseNFT: async (
      parent: any,
      { nftId, price }: { nftId: string; price: number },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Purchase> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Получаем NFT
      const nft = await prisma.nFT.findUnique({
        where: { id: nftId },
        include: { owner: true }
      })

      if (!nft) {
        throw new Error('NFT not found')
      }

      if (nft.ownerId === user.id) {
        throw new Error('Cannot purchase your own NFT')
      }

      if (nft.status !== 'LISTED') {
        throw new Error('NFT is not available for purchase')
      }

      if (nft.price !== price) {
        throw new Error('Price mismatch')
      }

      // В реальном проекте здесь была бы проверка баланса пользователя
      // Для демонстрации пропускаем эту проверку

      // Создаем транзакцию покупки
      const purchase = await prisma.purchase.create({
        data: {
          nftId,
          buyerId: user.id,
          sellerId: nft.ownerId,
          price,
          status: 'COMPLETED'
        },
        include: {
          nft: {
            include: {
              track: true,
              owner: true
            }
          },
          buyer: true,
          seller: true
        }
      })

      // Обновляем владельца NFT
      await prisma.nFT.update({
        where: { id: nftId },
        data: { 
          ownerId: user.id,
          status: 'OWNED'
        }
      })

      return purchase
    },

    listNFTForSale: async (
      parent: any,
      { nftId, price }: { nftId: string; price: number },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем NFT
      const nft = await prisma.nFT.findUnique({
        where: { id: nftId }
      })

      if (!nft || nft.ownerId !== user.id) {
        throw new Error('Access denied')
      }

      return prisma.nFT.update({
        where: { id: nftId },
        data: { 
          price,
          status: 'LISTED'
        },
        include: {
          track: true,
          owner: true
        }
      })
    },

    delistNFT: async (
      parent: any,
      { nftId }: { nftId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<NFT> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем NFT
      const nft = await prisma.nFT.findUnique({
        where: { id: nftId }
      })

      if (!nft || nft.ownerId !== user.id) {
        throw new Error('Access denied')
      }

      return prisma.nFT.update({
        where: { id: nftId },
        data: { 
          price: null,
          status: 'OWNED'
        },
        include: {
          track: true,
          owner: true
        }
      })
    },

    createStake: async (
      parent: any,
      { tokenId, amount }: { tokenId: string; amount: number },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Stake> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Получаем NFT
      const nft = await prisma.nFT.findUnique({
        where: { tokenId }
      })

      if (!nft) {
        throw new Error('NFT not found')
      }

      if (nft.ownerId !== user.id) {
        throw new Error('You can only stake NFTs you own')
      }

      // Создаем стейк через Web3 сервис
      const stakeResult = await web3Service.createStake(
        user.wallet || '',
        tokenId,
        amount
      )

      // Создаем запись в базе данных
      return prisma.stake.create({
        data: {
          userId: user.id,
          tokenId,
          amount,
          apy: 0.05, // 5% APY для демонстрации
          status: 'ACTIVE',
          rewards: 0
        },
        include: {
          token: true,
          user: true
        }
      })
    },

    unstake: async (
      parent: any,
      { stakeId }: { stakeId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Stake> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем стейка
      const stake = await prisma.stake.findUnique({
        where: { id: stakeId }
      })

      if (!stake || stake.userId !== user.id) {
        throw new Error('Access denied')
      }

      // Удаляем стейк через Web3 сервис
      await web3Service.unstake(user.wallet || '', stakeId)

      return prisma.stake.update({
        where: { id: stakeId },
        data: { 
          status: 'COMPLETED',
          endDate: new Date()
        },
        include: {
          token: true,
          user: true
        }
      })
    },

    claimStakingRewards: async (
      parent: any,
      { stakeId }: { stakeId: string },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<{ rewards: number; transactionHash: string }> => {
      if (!user) {
        throw new Error('Authentication required')
      }

      // Проверяем, что пользователь является владельцем стейка
      const stake = await prisma.stake.findUnique({
        where: { id: stakeId }
      })

      if (!stake || stake.userId !== user.id) {
        throw new Error('Access denied')
      }

      // Рассчитываем вознаграждения (для демонстрации)
      const rewards = stake.amount * stake.apy * 0.1 // 10% от стейкинга

      // В реальном проекте здесь была бы транзакция на блокчейне
      const transactionHash = '0x' + Math.random().toString(16).substr(2, 64)

      // Обновляем стейк
      await prisma.stake.update({
        where: { id: stakeId },
        data: { 
          rewards: { increment: rewards }
        }
      })

      return {
        rewards,
        transactionHash
      }
    }
  },

  NFT: {
    owner: (parent: NFT, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<User> => {
      return prisma.user.findUnique({
        where: { id: parent.ownerId }
      })
    },

    track: (parent: NFT, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Track | null> => {
      if (!parent.trackId) return Promise.resolve(null)
      return prisma.track.findUnique({
        where: { id: parent.trackId }
      })
    },

    purchases: (parent: NFT, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Purchase[]> => {
      return prisma.purchase.findMany({
        where: { nftId: parent.id },
        include: {
          buyer: true,
          seller: true
        }
      })
    },

    stakes: (parent: NFT, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Stake[]> => {
      return prisma.stake.findMany({
        where: { tokenId: parent.tokenId },
        include: {
          token: true,
          user: true
        }
      })
    },

    currentPrice: (parent: NFT, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): number => {
      return parent.price || 0
    },

    isOwnedByUser: async (parent: NFT, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      return parent.ownerId === user.id
    },

    canBeStaked: async (parent: NFT, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      return parent.ownerId === user.id && parent.status === 'OWNED'
    },

    canBeSold: async (parent: NFT, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      return parent.ownerId === user.id && parent.status === 'OWNED'
    }
  }
}