import { GraphQLResolveInfo } from 'graphql'
import { GraphQLContext } from '../types/context'
import { Connection, PublicKey, Transaction, SystemProgram, LAMPORTS_PER_SOL } from '@solana/web3.js'
import { getAssociatedTokenAddress, TOKEN_PROGRAM_ID, createAssociatedTokenAccountInstruction, createTransferInstruction, getAccount } from '@solana/spl-token'
import { DeflationaryModel } from '../../lib/deflationary-model'
import { Token, TokenType } from '@prisma/client'

interface Wallet {
  address: string
  balance: number
  publicKey: PublicKey
}

interface TransactionResult {
  signature: string
  success: boolean
  error?: string
}

interface MintResult {
  signature: string
  success: boolean
  error?: string
  tokenId?: string
}

interface StakeResult {
  signature: string
  success: boolean
  error?: string
  stakeId?: string
}

interface ProgramResponse {
  success: boolean
  data?: any
  error?: string
}

export const web3Resolvers = {
  Query: {
    walletBalance: async (
      parent: any,
      { address }: { address: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<number> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const publicKey = new PublicKey(address)
        
        const balance = await connection.getBalance(publicKey)
        return balance / LAMPORTS_PER_SOL
      } catch (error) {
        console.error('Error fetching wallet balance:', error)
        throw new Error('Failed to fetch wallet balance')
      }
    },

    walletTransactions: async (
      parent: any,
      { address, limit = 10 }: { address: string; limit?: number },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any[]> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const publicKey = new PublicKey(address)
        
        const signatures = await connection.getSignaturesForAddress(publicKey, {
          limit
        })
        
        const transactions = await connection.getParsedTransactions(signatures.map(sig => sig.signature))
        
        return transactions.map((tx, index) => ({
          signature: signatures[index].signature,
          slot: signatures[index].slot,
          blockTime: signatures[index].blockTime,
          success: tx?.meta?.err === null,
          fee: tx?.meta?.fee || 0,
          instructions: tx?.transaction.message.instructions || []
        }))
      } catch (error) {
        console.error('Error fetching wallet transactions:', error)
        throw new Error('Failed to fetch wallet transactions')
      }
    },

    tokenBalance: async (
      parent: any,
      { walletAddress, mintAddress }: { walletAddress: string; mintAddress: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<number> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const walletPublicKey = new PublicKey(walletAddress)
        const mintPublicKey = new PublicKey(mintAddress)
        
        const tokenAccount = await getAssociatedTokenAddress(mintPublicKey, walletPublicKey)
        
        const account = await getAccount(connection, tokenAccount)
        return Number(account.amount)
      } catch (error) {
        console.error('Error fetching token balance:', error)
        return 0
      }
    },

    programState: async (
      parent: any,
      { programId }: { programId: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<ProgramResponse> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const publicKey = new PublicKey(programId)
        
        // Получаем информацию о программе
        const accountInfo = await connection.getAccountInfo(publicKey)
        
        if (!accountInfo) {
          return {
            success: false,
            error: 'Program not found'
          }
        }
        
        return {
          success: true,
          data: {
            owner: accountInfo.owner.toBase58(),
            executable: accountInfo.executable,
            space: accountInfo.space,
            lamports: accountInfo.lamports
          }
        }
      } catch (error) {
        console.error('Error fetching program state:', error)
        return {
          success: false,
          error: 'Failed to fetch program state'
        }
      }
    },

    nftMetadata: async (
      parent: any,
      { mintAddress }: { mintAddress: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const mintPublicKey = new PublicKey(mintAddress)
        
        // Получаем метаданные NFT
        const token = await prisma.token.findFirst({
          where: { mintAddress }
        })
        
        if (!token) {
          throw new Error('Token not found')
        }
        
        return {
          mintAddress,
          name: token.name,
          symbol: token.symbol,
          decimals: token.decimals,
          totalSupply: token.totalSupply,
          metadata: token.metadata
        }
      } catch (error) {
        console.error('Error fetching NFT metadata:', error)
        throw new Error('Failed to fetch NFT metadata')
      }
    },

    stakingPoolInfo: async (
      parent: any,
      { poolAddress }: { poolAddress: string },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const publicKey = new PublicKey(poolAddress)
        
        // Получаем информацию о пуле стейкинга
        const accountInfo = await connection.getAccountInfo(publicKey)
        
        if (!accountInfo) {
          throw new Error('Staking pool not found')
        }
        
        // Здесь можно добавить логику для парсинга данных пула
        return {
          address: poolAddress,
          totalStaked: 0, // TODO: Получить из программы
          totalRewards: 0, // TODO: Получить из программы
          apy: 5.0, // TODO: Получить из программы
          minimumStake: 1, // TODO: Получить из программы
        }
      } catch (error) {
        console.error('Error fetching staking pool info:', error)
        throw new Error('Failed to fetch staking pool info')
      }
    },

    deflationaryStats: async (
      parent: any,
      args: any,
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      try {
        // Получаем общую статистику для дефляционных токенов
        const tokens = await prisma.token.findMany({
          where: { type: 'DEFLATIONARY' }
        })
        
        const totalSupply = tokens.reduce((sum, token) => sum + token.totalSupply, 0)
        const totalBurned = tokens.reduce((sum, token) => sum + (token.totalSupply * 0.02), 0) // 2% burn rate
        
        return {
          totalTokens: tokens.length,
          totalSupply,
          totalBurned,
          burnRate: 2.0, // 2%
          averageAPY: 5.0 // TODO: Рассчитать реальное среднее значение
        }
      } catch (error) {
        console.error('Error fetching deflationary stats:', error)
        throw new Error('Failed to fetch deflationary stats')
      }
    }
  },

  Mutation: {
    transferSol: async (
      parent: any,
      { fromAddress, toAddress, amount, privateKey }: { 
        fromAddress: string; 
        toAddress: string; 
        amount: number; 
        privateKey: string; 
      },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<TransactionResult> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const fromPublicKey = new PublicKey(fromAddress)
        const toPublicKey = new PublicKey(toAddress)
        
        // Создаем транзакцию перевода SOL
        const transaction = new Transaction().add(
          SystemProgram.transfer({
            fromPubkey: fromPublicKey,
            toPubkey: toPublicKey,
            lamports: amount * LAMPORTS_PER_SOL
          })
        )
        
        // Подписываем транзакцию (в реальном приложении здесь будет подпись кошелька)
        // TODO: Реализовать подпись через кошелек
        const signature = await connection.sendRawTransaction(transaction.serialize())
        
        // Ждем подтверждения
        await connection.confirmTransaction(signature)
        
        return {
          signature,
          success: true
        }
      } catch (error) {
        console.error('Error transferring SOL:', error)
        return {
          signature: '',
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    },

    transferToken: async (
      parent: any,
      { fromAddress, toAddress, mintAddress, amount, privateKey }: { 
        fromAddress: string; 
        toAddress: string; 
        mintAddress: string; 
        amount: number; 
        privateKey: string; 
      },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<TransactionResult> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const fromPublicKey = new PublicKey(fromAddress)
        const toPublicKey = new PublicKey(toAddress)
        const mintPublicKey = new PublicKey(mintAddress)
        
        // Получаем адреса токен-аккаунтов
        const fromTokenAccount = await getAssociatedTokenAddress(mintPublicKey, fromPublicKey)
        const toTokenAccount = await getAssociatedTokenAddress(mintPublicKey, toPublicKey)
        
        // Создаем транзакцию перевода токенов
        const transaction = new Transaction().add(
          createTransferInstruction(
            fromTokenAccount,
            toTokenAccount,
            fromPublicKey,
            amount
          )
        )
        
        // Подписываем транзакцию
        // TODO: Реализовать подпись через кошелек
        const signature = await connection.sendRawTransaction(transaction.serialize())
        
        // Ждем подтверждения
        await connection.confirmTransaction(signature)
        
        return {
          signature,
          success: true
        }
      } catch (error) {
        console.error('Error transferring token:', error)
        return {
          signature: '',
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    },

    mintNFT: async (
      parent: any,
      { 
        creatorAddress, 
        metadata, 
        royaltyPercentage, 
        privateKey 
      }: { 
        creatorAddress: string; 
        metadata: any; 
        royaltyPercentage: number; 
        privateKey: string; 
      },
      { prisma }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<MintResult> => {
      try {
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const creatorPublicKey = new PublicKey(creatorAddress)
        
        // Генерируем уникальный токен ID
        const tokenId = Math.random().toString(36).substr(2, 9)
        
        // Создаем транзакцию минтинга NFT
        // TODO: Реализовать вызов Anchor программы для минтинга
        const signature = await connection.sendRawTransaction(new Transaction().serialize())
        
        // Ждем подтверждения
        await connection.confirmTransaction(signature)
        
        // Сохраняем информацию в базу данных
        await prisma.token.create({
          data: {
            id: tokenId,
            name: metadata.name,
            symbol: metadata.symbol || 'NFT',
            type: 'NFT',
            decimals: 0,
            totalSupply: 1,
            metadata: metadata,
            creatorAddress: creatorAddress,
            royaltyPercentage,
            mintAddress: signature, // В реальности это будет адрес токена
            createdAt: new Date(),
            updatedAt: new Date()
          }
        })
        
        return {
          signature,
          success: true,
          tokenId
        }
      } catch (error) {
        console.error('Error minting NFT:', error)
        return {
          signature: '',
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    },

    stakeTokens: async (
      parent: any,
      { 
        walletAddress, 
        tokenAddress, 
        amount, 
        duration, 
        privateKey 
      }: { 
        walletAddress: string; 
        tokenAddress: string; 
        amount: number; 
        duration: number; 
        privateKey: string; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<StakeResult> => {
      try {
        if (!user) {
          throw new Error('Authentication required')
        }
        
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        const walletPublicKey = new PublicKey(walletAddress)
        
        // Проверяем баланс токенов
        const tokenBalance = await web3Resolvers.Query.tokenBalance(
          null, 
          { walletAddress, mintAddress: tokenAddress }, 
          { prisma }, 
          info
        )
        
        if (tokenBalance < amount) {
          throw new Error('Insufficient token balance')
        }
        
        // Создаем транзакцию стейкинга
        // TODO: Реализовать вызов Anchor программы для стейкинга
        const signature = await connection.sendRawTransaction(new Transaction().serialize())
        
        // Ждем подтверждения
        await connection.confirmTransaction(signature)
        
        // Рассчитываем вознаграждение с учетом дефляционной модели
        const deflationaryModel = new DeflationaryModel()
        const rewardRate = deflationaryModel.calculateRewardRate(amount, duration)
        
        // Сохраняем информацию о стейке в базу данных
        const stake = await prisma.stake.create({
          data: {
            userId: user.id,
            tokenId: tokenAddress,
            amount,
            rewardRate,
            earned: 0,
            status: 'ACTIVE',
            startDate: new Date(),
            endDate: new Date(Date.now() + duration * 24 * 60 * 60 * 1000), // duration в днях
            apy: rewardRate * 100 / amount * 365, // Годовая процентная ставка
            createdAt: new Date(),
            updatedAt: new Date()
          }
        })
        
        return {
          signature,
          success: true,
          stakeId: stake.id
        }
      } catch (error) {
        console.error('Error staking tokens:', error)
        return {
          signature: '',
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    },

    unstakeTokens: async (
      parent: any,
      { 
        stakeId, 
        privateKey 
      }: { 
        stakeId: string; 
        privateKey: string; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<TransactionResult> => {
      try {
        if (!user) {
          throw new Error('Authentication required')
        }
        
        // Проверяем, что стейк принадлежит пользователю
        const stake = await prisma.stake.findUnique({
          where: { id: stakeId }
        })
        
        if (!stake || stake.userId !== user.id) {
          throw new Error('Stake not found or access denied')
        }
        
        if (stake.status !== 'ACTIVE') {
          throw new Error('Stake is not active')
        }
        
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        
        // Создаем транзакцию вывода стейкинга
        // TODO: Реализовать вызов Anchor программы для вывода
        const signature = await connection.sendRawTransaction(new Transaction().serialize())
        
        // Ждем подтверждения
        await connection.confirmTransaction(signature)
        
        // Обновляем статус стейка
        await prisma.stake.update({
          where: { id: stakeId },
          data: { 
            status: 'COMPLETED',
            updatedAt: new Date()
          }
        })
        
        return {
          signature,
          success: true
        }
      } catch (error) {
        console.error('Error unstaking tokens:', error)
        return {
          signature: '',
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    },

    claimRewards: async (
      parent: any,
      { 
        stakeId, 
        privateKey 
      }: { 
        stakeId: string; 
        privateKey: string; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<TransactionResult> => {
      try {
        if (!user) {
          throw new Error('Authentication required')
        }
        
        // Проверяем, что стейк принадлежит пользователю
        const stake = await prisma.stake.findUnique({
          where: { id: stakeId }
        })
        
        if (!stake || stake.userId !== user.id) {
          throw new Error('Stake not found or access denied')
        }
        
        if (stake.status !== 'ACTIVE') {
          throw new Error('Stake is not active')
        }
        
        const connection = new Connection(process.env.SOLANA_NETWORK || 'devnet')
        
        // Создаем транзакцию получения вознаграждений
        // TODO: Реализовать вызов Anchor программы для получения вознаграждений
        const signature = await connection.sendRawTransaction(new Transaction().serialize())
        
        // Ждем подтверждения
        await connection.confirmTransaction(signature)
        
        // Обновляем стейк и создаем запись о вознаграждении
        await prisma.stake.update({
          where: { id: stakeId },
          data: { 
            earned: 0, // Сбрасываем заработанное
            updatedAt: new Date()
          }
        })
        
        await prisma.reward.create({
          data: {
            userId: user.id,
            amount: stake.earned,
            type: 'STAKING',
            reason: 'Claimed staking rewards',
            status: 'COMPLETED',
            createdAt: new Date(),
            updatedAt: new Date()
          }
        })
        
        return {
          signature,
          success: true
        }
      } catch (error) {
        console.error('Error claiming rewards:', error)
        return {
          signature: '',
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    },

    createDeflationaryToken: async (
      parent: any,
      { 
        name, 
        symbol, 
        initialSupply, 
        burnRate, 
        metadata 
      }: { 
        name: string; 
        symbol: string; 
        initialSupply: number; 
        burnRate: number; 
        metadata: any; 
      },
      { prisma, user }: GraphQLContext,
      info: GraphQLResolveInfo
    ): Promise<any> => {
      try {
        if (!user) {
          throw new Error('Authentication required')
        }
        
        // Создаем дефляционный токен
        const token = await prisma.token.create({
          data: {
            name,
            symbol,
            type: 'DEFLATIONARY',
            decimals: 9, // Стандарт для SPL токенов
            totalSupply: initialSupply,
            metadata,
            burnRate,
            creatorAddress: user.wallet || '',
            createdAt: new Date(),
            updatedAt: new Date()
          }
        })
        
        // Рассчитываем количество токенов после сжигания
        const deflationaryModel = new DeflationaryModel()
        const burnedAmount = deflationaryModel.calculateBurn(initialSupply)
        const finalSupply = initialSupply - burnedAmount
        
        return {
          success: true,
          token: {
            ...token,
            finalSupply,
            burnedAmount
          }
        }
      } catch (error) {
        console.error('Error creating deflationary token:', error)
        return {
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error'
        }
      }
    }
  }
}