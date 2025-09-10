import { GraphQLResolveInfo } from 'graphql'
import { GraphQLContext } from '../types/context'

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

interface Reward {
  id: string
  userId: string
  amount: number
  type: string
  description?: string
  status: string
  transactionHash?: string
  createdAt: Date
  updatedAt: Date
}

// Mock Web3 сервис для демонстрации
class StakingService {
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

  async claimRewards(
    wallet: string,
    stakeId: string
  ): Promise<{ transactionHash: string; rewards: number }> {
    // В реальном проекте здесь была бы интеграция с Solana
    return {
      transactionHash: '0xabcdef1234567890abcdef1234567890abcdef',
      rewards: Math.random() * 100
    }
  }

  async getStakingRewards(
    wallet: string,
    tokenId: string
  ): Promise<number> {
    // В реальном проекте здесь был бы запрос к блокчейну
    return Math.random() * 50
  }
}

const stakingService = new StakingService()

export const stakingResolvers = {
  Query: {
    stake: async (
      parent: any,
      { id }: { id: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Stake | null> => {
      return prisma.stake.findUnique({
        where: { id },
        include: {
          user: true,
          token: true,
          nft: true
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
          user: true,
          token: true,
          nft: true
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
          user: true,
          token: true,
          nft: true
        }
      })
    },

    activeStakes: async (
      parent: any,
      { limit = 50, offset = 0 }: { limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Stake[]> => {
      return prisma.stake.findMany({
        where: { status: 'ACTIVE' },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: true,
          token: true,
          nft: true
        }
      })
    },

    stakeHistory: async (
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
          user: true,
          token: true,
          nft: true
        }
      })
    },

    stakingRewards: async (
      parent: any,
      { userId, limit = 50, offset = 0 }: { userId: string; limit?: number; offset?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Reward[]> => {
      return prisma.reward.findMany({
        where: { 
          userId,
          type: 'STAKING'
        },
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' }
      })
    },

    totalStakedAmount: async (
      parent: any,
      { userId }: { userId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<number> => {
      const stakes = await prisma.stake.findMany({
        where: { 
          userId,
          status: 'ACTIVE'
        }
      })

      return stakes.reduce((sum, stake) => sum + stake.amount, 0)
    },

    totalEarnedRewards: async (
      parent: any,
      { userId }: { userId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<number> => {
      const result = await prisma.reward.aggregate({
        where: { 
          userId,
          type: 'STAKING',
          status: 'COMPLETED'
        },
        _sum: { amount: true }
      })

      return result._sum.amount || 0
    },

    stakingStats: async (
      parent: any,
      { userId }: { userId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      const activeStakes = await prisma.stake.findMany({
        where: { 
          userId,
          status: 'ACTIVE'
        }
      })

      const totalStaked = activeStakes.reduce((sum, stake) => sum + stake.amount, 0)
      const totalRewards = await stakingResolvers.Query.totalEarnedRewards(parent, { userId }, { prisma }, info)
      
      // Рассчитываем текущие вознаграждения
      let currentRewards = 0
      for (const stake of activeStakes) {
        const daysStaked = Math.floor((new Date().getTime() - stake.startDate.getTime()) / (1000 * 60 * 60 * 24))
        const yearlyRewards = stake.amount * (stake.apy / 100)
        const dailyRewards = yearlyRewards / 365
        currentRewards += dailyRewards * daysStaked
      }

      return {
        totalStaked,
        totalRewards,
        currentRewards,
        activeStakesCount: activeStakes.length,
        averageAPY: activeStakes.length > 0 
          ? activeStakes.reduce((sum, stake) => sum + stake.apy, 0) / activeStakes.length 
          : 0
      }
    },

    availableStakingTokens: async (
      parent: any,
      args: any,
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<Token[]> => {
      // В реальном проекте здесь был бы запрос к токенам, доступным для стейкинга
      // Для демонстрации возвращаем моковые данные
      return []
    }
  },

  Mutation: {
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

      // Проверяем, что NFT еще не стейкнут
      const existingStake = await prisma.stake.findFirst({
        where: { 
          tokenId,
          status: 'ACTIVE'
        }
      })

      if (existingStake) {
        throw new Error('NFT is already staked')
      }

      // Создаем стейк через Web3 сервис
      const stakeResult = await stakingService.createStake(
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
          rewards: 0,
          startDate: new Date()
        },
        include: {
          user: true,
          token: true,
          nft: true
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

      if (stake.status !== 'ACTIVE') {
        throw new Error('Stake is not active')
      }

      // Удаляем стейк через Web3 сервис
      await stakingService.unstake(user.wallet || '', stakeId)

      // Обновляем стейк
      return prisma.stake.update({
        where: { id: stakeId },
        data: { 
          status: 'COMPLETED',
          endDate: new Date()
        },
        include: {
          user: true,
          token: true,
          nft: true
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

      if (stake.status !== 'ACTIVE') {
        throw new Error('Stake is not active')
      }

      // Рассчитываем вознаграждения
      const daysStaked = Math.floor((new Date().getTime() - stake.startDate.getTime()) / (1000 * 60 * 60 * 24))
      const yearlyRewards = stake.amount * (stake.apy / 100)
      const dailyRewards = yearlyRewards / 365
      const rewards = dailyRewards * daysStaked

      if (rewards <= 0) {
        throw new Error('No rewards to claim')
      }

      // Кланим вознаграждения через Web3 сервис
      const claimResult = await stakingService.claimRewards(
        user.wallet || '',
        stakeId
      )

      // Создаем запись о вознаграждении
      await prisma.reward.create({
        data: {
          userId: user.id,
          amount: rewards,
          type: 'STAKING',
          description: `Staking rewards for NFT ${stake.tokenId}`,
          status: 'COMPLETED',
          transactionHash: claimResult.transactionHash
        }
      })

      // Обновляем стейк
      await prisma.stake.update({
        where: { id: stakeId },
        data: { 
          rewards: { increment: rewards }
        }
      })

      return {
        rewards,
        transactionHash: claimResult.transactionHash
      }
    },

    compoundRewards: async (
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

      if (stake.status !== 'ACTIVE') {
        throw new Error('Stake is not active')
      }

      // Рассчитываем вознаграждения
      const daysStaked = Math.floor((new Date().getTime() - stake.startDate.getTime()) / (1000 * 60 * 60 * 24))
      const yearlyRewards = stake.amount * (stake.apy / 100)
      const dailyRewards = yearlyRewards / 365
      const rewards = dailyRewards * daysStaked

      if (rewards <= 0) {
        throw new Error('No rewards to compound')
      }

      // В реальном проекте здесь была бы транзакция на блокчейне
      const transactionHash = '0x' + Math.random().toString(16).substr(2, 64)

      // Обновляем стейк с капитализацией вознаграждений
      return prisma.stake.update({
        where: { id: stakeId },
        data: { 
          amount: { increment: rewards },
          rewards: 0, // Сбрасываем вознаграждения
          startDate: new Date() // Обновляем дату начала для нового периода
        },
        include: {
          user: true,
          token: true,
          nft: true
        }
      })
    },

    updateStakeAPY: async (
      parent: any,
      { stakeId, apy }: { stakeId: string; apy: number },
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

      // В реальном проекте здесь была бы проверка прав на изменение APY
      // Для демонстрации просто обновляем

      return prisma.stake.update({
        where: { id: stakeId },
        data: { apy },
        include: {
          user: true,
          token: true,
          nft: true
        }
      })
    }
  },

  Stake: {
    user: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<User> => {
      return prisma.user.findUnique({
        where: { id: parent.userId }
      })
    },

    nft: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<NFT> => {
      return prisma.nFT.findUnique({
        where: { tokenId: parent.tokenId }
      })
    },

    token: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): Promise<Token> => {
      return prisma.token.findUnique({
        where: { id: parent.tokenId }
      })
    },

    duration: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): number => {
      if (!parent.startDate) return 0
      const endDate = parent.endDate || new Date()
      const diffTime = Math.abs(endDate.getTime() - parent.startDate.getTime())
      return Math.ceil(diffTime / (1000 * 60 * 60 * 24)) // В днях
    },

    dailyRewards: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): number => {
      const yearlyRewards = parent.amount * (parent.apy / 100)
      return yearlyRewards / 365
    },

    totalRewards: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): number => {
      return parent.rewards || 0
    },

    roi: (parent: Stake, args: any, { prisma }: GraphQLContext, info: GraphQLResolveInfo): number => {
      if (!parent.startDate || parent.rewards === 0) return 0
      const duration = parent.duration
      if (duration === 0) return 0
      return (parent.rewards / parent.amount) * (365 / duration) * 100 // Годовой ROI в %
    },

    canClaim: async (parent: Stake, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      if (parent.userId !== user.id) return false
      if (parent.status !== 'ACTIVE') return false

      // Рассчитываем вознаграждения
      const daysStaked = Math.floor((new Date().getTime() - parent.startDate.getTime()) / (1000 * 60 * 60 * 24))
      const yearlyRewards = parent.amount * (parent.apy / 100)
      const dailyRewards = yearlyRewards / 365
      const rewards = dailyRewards * daysStaked

      return rewards > 0
    },

    canCompound: async (parent: Stake, args: any, { prisma, user }: GraphQLContext, info: GraphQLResolveInfo): Promise<boolean> => {
      if (!user) return false
      if (parent.userId !== user.id) return false
      if (parent.status !== 'ACTIVE') return false

      // Рассчитываем вознаграждения
      const daysStaked = Math.floor((new Date().getTime() - parent.startDate.getTime()) / (1000 * 60 * 60 * 24))
      const yearlyRewards = parent.amount * (parent.apy / 100)
      const dailyRewards = yearlyRewards / 365
      const rewards = dailyRewards * daysStaked

      return rewards > 0
    }
  }
}