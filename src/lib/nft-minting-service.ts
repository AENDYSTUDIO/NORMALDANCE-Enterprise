import { createHash } from 'crypto'
import { DeflationaryModel } from './deflationary-model'
import { ipfsService } from './ipfs-enhanced'
import { filecoinService } from './filecoin-service'

// Интерфейс для NFT metadata
export interface NFTMetadata {
  name: string
  description: string
  image: string
  animation_url?: string
  external_url?: string
  attributes: NFTAttribute[]
  background_color?: string
  properties?: Record<string, any>
}

// Интерфейс для атрибутов NFT
export interface NFTAttribute {
  trait_type: string
  value: string | number
  display_type?: 'number' | 'boost_percentage' | 'boost_number'
  max_value?: number
}

// Интерфейс для NFT коллекции
export interface NFTCollection {
  id: string
  name: string
  symbol: string
  description: string
  image: string
  banner?: string
  maxSupply: number
  currentSupply: number
  royaltyPercentage: number
  royaltyAddress: string
  creators: Creator[]
  category: string
  tags: string[]
  attributes: NFTAttribute[]
  isMutable: boolean
  isExplicit: boolean
  createdAt: Date
  updatedAt: Date
}

// Интерфейс для создателя
export interface Creator {
  address: string
  share: number
  verified: boolean
}

// Интерфейс для минтинга NFT
export interface MintRequest {
  collectionId: string
  metadata: NFTMetadata
  price: number
  quantity?: number
  toAddress: string
  royaltyPercentage?: number
  royaltyAddress?: string
  tokenMint?: boolean
  walletAddress: string
  signature?: string
}

// Интерфейс для транзакции минтинга
export interface MintTransaction {
  id: string
  collectionId: string
  mintAddress: string
  tokenAddress: string
  tokenIds: string[]
  metadata: NFTMetadata
  price: number
  quantity: number
  royaltyPercentage: number
  royaltyAddress: string
  transactionHash: string
  blockNumber: number
  status: 'pending' | 'confirmed' | 'failed'
  createdAt: Date
  confirmedAt?: Date
  errorMessage?: string
}

// Интерфейс для роялти
export interface Royalty {
  id: string
  nftId: string
  recipient: string
  percentage: number
  amount: number
  tokenId: string
  transactionHash: string
  createdAt: Date
  claimed: boolean
  claimedAt?: Date
}

// Типы NFT
export enum NFTType {
  TRACK = 'track',
  ALBUM = 'album',
  PLAYLIST = 'playlist',
  ARTIST = 'artist',
  COLLECTIBLE = 'collectible',
  FRACTIONAL = 'fractional'
}

// Статусы NFT
export enum NFTStatus {
  LISTED = 'listed',
  SOLD = 'sold',
  MINTED = 'minted',
  TRANSFERRED = 'transferred',
  BURNED = 'burned',
  CANCELED = 'canceled'
}

// Класс для NFT минтинга
export class NFTMintingService {
  private deflationaryModel: DeflationaryModel
  private collections: Map<string, NFTCollection> = new Map()
  private mintTransactions: Map<string, MintTransaction> = new Map()
  private royalties: Map<string, Royalty> = new Map()

  constructor() {
    this.deflationaryModel = new DeflationaryModel({ symbol: 'NDT', decimals: 9 })
  }

  // Создание коллекции NFT
  async createCollection(collection: Omit<NFTCollection, 'id' | 'currentSupply' | 'createdAt' | 'updatedAt'>): Promise<NFTCollection> {
    const collectionId = this.generateCollectionId()
    const now = new Date()

    const newCollection: NFTCollection = {
      ...collection,
      id: collectionId,
      currentSupply: 0,
      createdAt: now,
      updatedAt: now
    }

    this.collections.set(collectionId, newCollection)

    // Загружаем метаданные в IPFS
    const metadata = await this.uploadCollectionMetadata(newCollection)
    newCollection.image = metadata.image
    newCollection.banner = metadata.banner

    return newCollection
  }

  // Получение коллекции
  async getCollection(collectionId: string): Promise<NFTCollection | null> {
    return this.collections.get(collectionId) || null
  }

  // Получение всех коллекций
  async getAllCollections(filters?: {
    category?: string
    tags?: string[]
    minSupply?: number
    maxSupply?: number
    limit?: number
    offset?: number
  }): Promise<NFTCollection[]> {
    let collections = Array.from(this.collections.values())

    if (filters?.category) {
      collections = collections.filter(c => c.category === filters.category)
    }
    if (filters?.tags) {
      collections = collections.filter(c => 
        filters.tags!.some(tag => c.tags.includes(tag))
      )
    }
    if (filters?.minSupply) {
      collections = collections.filter(c => c.currentSupply >= filters.minSupply!)
    }
    if (filters?.maxSupply) {
      collections = collections.filter(c => c.currentSupply <= filters.maxSupply!)
    }

    collections.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())

    if (filters?.limit) {
      collections = collections.slice(0, filters.limit)
    }
    if (filters?.offset) {
      collections = collections.slice(filters.offset)
    }

    return collections
  }

  // Минтинг NFT
  async mintNFT(mintRequest: MintRequest): Promise<MintTransaction> {
    const collection = await this.getCollection(mintRequest.collectionId)
    if (!collection) {
      throw new Error('Collection not found')
    }

    if (collection.currentSupply >= collection.maxSupply) {
      throw new Error('Collection supply exceeded')
    }

    // Проверка цены
    if (mintRequest.price < 0) {
      throw new Error('Price cannot be negative')
    }

    // Генерация транзакции
    const transactionId = this.generateTransactionId()
    const now = new Date()

    const mintTransaction: MintTransaction = {
      id: transactionId,
      collectionId: mintRequest.collectionId,
      mintAddress: mintRequest.toAddress,
      tokenAddress: collection.id,
      tokenIds: [],
      metadata: mintRequest.metadata,
      price: mintRequest.price,
      quantity: mintRequest.quantity || 1,
      royaltyPercentage: mintRequest.royaltyPercentage || collection.royaltyPercentage,
      royaltyAddress: mintRequest.royaltyAddress || collection.royaltyAddress,
      transactionHash: '',
      blockNumber: 0,
      status: 'pending',
      createdAt: now
    }

    // Загрузка метаданных в IPFS
    const metadataHash = await this.uploadNFTMetadata(mintRequest.metadata)
    mintTransaction.metadata.image = metadataHash

    // Здесь должна быть логика взаимодействия с блокчейном
    // Для примера симулируем транзакцию
    setTimeout(async () => {
      try {
        // Генерация токенов
        const tokenIds = this.generateTokenIds(mintTransaction.quantity)
        mintTransaction.tokenIds = tokenIds
        mintTransaction.transactionHash = `0x${createHash('sha256').update(transactionId).digest('hex').slice(0, 64)}`
        mintTransaction.blockNumber = await this.getCurrentBlockNumber()
        mintTransaction.status = 'confirmed'
        mintTransaction.confirmedAt = new Date()

        // Обновление коллекции
        collection.currentSupply += mintTransaction.quantity
        collection.updatedAt = new Date()

        // Создание записей о роялти
        await this.createRoyalties(mintTransaction)

        this.mintTransactions.set(transactionId, mintTransaction)
      } catch (error) {
        mintTransaction.status = 'failed'
        mintTransaction.errorMessage = error instanceof Error ? error.message : 'Unknown error'
        this.mintTransactions.set(transactionId, mintTransaction)
      }
    }, 2000)

    this.mintTransactions.set(transactionId, mintTransaction)
    return mintTransaction
  }

  // Получение транзакции минтинга
  async getMintTransaction(transactionId: string): Promise<MintTransaction | null> {
    return this.mintTransactions.get(transactionId) || null
  }

  // Получение всех транзакций
  async getAllMintTransactions(filters?: {
    collectionId?: string
    status?: MintTransaction['status']
    walletAddress?: string
    limit?: number
    offset?: number
  }): Promise<MintTransaction[]> {
    let transactions = Array.from(this.mintTransactions.values())

    if (filters?.collectionId) {
      transactions = transactions.filter(t => t.collectionId === filters.collectionId)
    }
    if (filters?.status) {
      transactions = transactions.filter(t => t.status === filters.status)
    }
    if (filters?.walletAddress) {
      transactions = transactions.filter(t => 
        t.mintAddress === filters.walletAddress || 
        t.royaltyAddress === filters.walletAddress
      )
    }

    transactions.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())

    if (filters?.limit) {
      transactions = transactions.slice(0, filters.limit)
    }
    if (filters?.offset) {
      transactions = transactions.slice(filters.offset)
    }

    return transactions
  }

  // Получение роялти для NFT
  async getRoyalties(nftId: string): Promise<Royalty[]> {
    return Array.from(this.royalties.values()).filter(r => r.nftId === nftId)
  }

  // Получение всех роялти
  async getAllRoyalties(filters?: {
    recipient?: string
    claimed?: boolean
    limit?: number
    offset?: number
  }): Promise<Royalty[]> {
    let royalties = Array.from(this.royalties.values())

    if (filters?.recipient) {
      royalties = royalties.filter(r => r.recipient === filters.recipient)
    }
    if (filters?.claimed !== undefined) {
      royalties = royalties.filter(r => r.claimed === filters.claimed)
    }

    royalties.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())

    if (filters?.limit) {
      royalties = royalties.slice(0, filters.limit)
    }
    if (filters?.offset) {
      royalties = royalties.slice(filters.offset)
    }

    return royalties
  }

  // Получение роялти для получателя
  async getRoyaltiesForRecipient(recipient: string): Promise<Royalty[]> {
    return Array.from(this.royalties.values()).filter(r => r.recipient === recipient)
  }

  // Получение невостребованных роялти
  async getUnclaimedRoyalties(recipient: string): Promise<Royalty[]> {
    return Array.from(this.royalties.values()).filter(r => 
      r.recipient === recipient && !r.claimed
    )
  }

  // Взыскание роялти
  async claimRoyalty(royaltyId: string, recipient: string): Promise<{ success: boolean; message: string; txHash?: string }> {
    const royalty = this.royalties.get(royaltyId)
    if (!royalty) {
      return { success: false, message: 'Royalty not found' }
    }

    if (royalty.recipient !== recipient) {
      return { success: false, message: 'Not authorized to claim this royalty' }
    }

    if (royalty.claimed) {
      return { success: false, message: 'Royalty already claimed' }
    }

    // Здесь должна быть логика отправки средств
    // Для примера симулируем транзакцию
    const txHash = `0x${createHash('sha256').update(royaltyId + recipient + Date.now()).digest('hex').slice(0, 64)}`

    royalty.claimed = true
    royalty.claimedAt = new Date()

    return {
      success: true,
      message: 'Royalty claimed successfully',
      txHash
    }
  }

  // Получение статистики NFT
  async getNFTStats(): Promise<{
    totalCollections: number
    totalNFTs: number
    totalVolume: number
    averagePrice: number
    topCollections: NFTCollection[]
    recentTransactions: MintTransaction[]
  }> {
    const collections = Array.from(this.collections.values())
    const transactions = Array.from(this.mintTransactions.values())
    const confirmedTransactions = transactions.filter(t => t.status === 'confirmed')

    const totalNFTs = collections.reduce((sum, c) => sum + c.currentSupply, 0)
    const totalVolume = confirmedTransactions.reduce((sum, t) => sum + (t.price * t.quantity), 0)
    const averagePrice = confirmedTransactions.length > 0 
      ? totalVolume / confirmedTransactions.reduce((sum, t) => sum + t.quantity, 0)
      : 0

    const topCollections = collections
      .sort((a, b) => b.currentSupply - a.currentSupply)
      .slice(0, 5)

    const recentTransactions = confirmedTransactions
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, 10)

    return {
      totalCollections: collections.length,
      totalNFTs,
      totalVolume,
      averagePrice,
      topCollections,
      recentTransactions
    }
  }

  // Проверка валидности метаданных
  async validateMetadata(metadata: NFTMetadata): Promise<{ valid: boolean; errors: string[] }> {
    const errors: string[] = []

    if (!metadata.name || metadata.name.length > 100) {
      errors.push('Name must be between 1 and 100 characters')
    }

    if (!metadata.description || metadata.description.length > 2000) {
      errors.push('Description must be between 1 and 2000 characters')
    }

    if (!metadata.image) {
      errors.push('Image is required')
    }

    if (!metadata.attributes || metadata.attributes.length === 0) {
      errors.push('At least one attribute is required')
    }

    // Проверка атрибутов
    metadata.attributes.forEach((attr, index) => {
      if (!attr.trait_type || attr.trait_type.length > 100) {
        errors.push(`Attribute ${index + 1}: trait_type must be between 1 and 100 characters`)
      }
      if (attr.value === undefined || attr.value === null) {
        errors.push(`Attribute ${index + 1}: value is required`)
      }
    })

    return {
      valid: errors.length === 0,
      errors
    }
  }

  // Получение текущего блока
  private async getCurrentBlockNumber(): Promise<number> {
    // Здесь должна быть логика получения текущего блока из блокчейна
    // Для примера возвращаем случайное число
    return Math.floor(Math.random() * 1000000) + 1
  }

  // Загрузка метаданных коллекции в IPFS
  private async uploadCollectionMetadata(collection: NFTCollection): Promise<{ image: string; banner?: string }> {
    const metadata = {
      name: collection.name,
      description: collection.description,
      image: collection.image,
      banner: collection.banner,
      external_url: `https://normaldance.com/collection/${collection.id}`,
      attributes: collection.attributes,
      category: collection.category,
      tags: collection.tags,
      max_supply: collection.maxSupply,
      current_supply: collection.currentSupply,
      royalty_percentage: collection.royaltyPercentage,
      creators: collection.creators,
      is_mutable: collection.isMutable,
      is_explicit: collection.isExplicit
    }

    const imageHash = await ipfsService.uploadFile(collection.image, 'image/jpeg')
    const bannerHash = collection.banner ? await ipfsService.uploadFile(collection.banner, 'image/jpeg') : undefined

    return {
      image: imageHash,
      banner: bannerHash
    }
  }

  // Загрузка метаданных NFT в IPFS
  private async uploadNFTMetadata(metadata: NFTMetadata): Promise<string> {
    const metadataCopy = { ...metadata }
    
    // Заменяем URL на IPFS хэши
    if (metadataCopy.image && metadataCopy.image.startsWith('http')) {
      metadataCopy.image = await ipfsService.uploadFile(metadataCopy.image, 'image/jpeg')
    }
    
    if (metadataCopy.animation_url && metadataCopy.animation_url.startsWith('http')) {
      metadataCopy.animation_url = await ipfsService.uploadFile(metadataCopy.animation_url, 'audio/mpeg')
    }

    // Загружаем метаданные в IPFS
    const metadataString = JSON.stringify(metadataCopy, null, 2)
    const metadataBuffer = Buffer.from(metadataString)
    
    return await ipfsService.uploadFile(metadataBuffer, 'application/json')
  }

  // Создание записей о роялти
  private async createRoyalties(transaction: MintTransaction): Promise<void> {
    const royaltyAmount = transaction.price * (transaction.royaltyPercentage / 100)
    
    for (const tokenId of transaction.tokenIds) {
      const royalty: Royalty = {
        id: this.generateRoyaltyId(),
        nftId: tokenId,
        recipient: transaction.royaltyAddress,
        percentage: transaction.royaltyPercentage,
        amount: royaltyAmount,
        tokenId,
        transactionHash: transaction.transactionHash,
        createdAt: new Date(),
        claimed: false
      }
      
      this.royalties.set(royalty.id, royalty)
    }
  }

  // Генерация ID коллекции
  private generateCollectionId(): string {
    return `collection_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  // Генерация ID транзакции
  private generateTransactionId(): string {
    return `tx_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  // Генерация ID роялти
  private generateRoyaltyId(): string {
    return `royalty_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  // Генерация токенов
  private generateTokenIds(quantity: number): string[] {
    const tokenIds: string[] = []
    for (let i = 0; i < quantity; i++) {
      tokenIds.push(`token_${Date.now()}_${Math.random().toString(36).substr(2, 9)}_${i}`)
    }
    return tokenIds
  }

  // Получение коллекций по категории
  async getCollectionsByCategory(category: string): Promise<NFTCollection[]> {
    return Array.from(this.collections.values()).filter(c => c.category === category)
  }

  // Получение коллекций по тегам
  async getCollectionsByTags(tags: string[]): Promise<NFTCollection[]> {
    return Array.from(this.collections.values()).filter(c =>
      tags.some(tag => c.tags.includes(tag))
    )
  }

  // Поиск NFT
  async searchNFT(query: string): Promise<NFTCollection[]> {
    const searchTerm = query.toLowerCase()
    return Array.from(this.collections.values()).filter(c =>
      c.name.toLowerCase().includes(searchTerm) ||
      c.description.toLowerCase().includes(searchTerm) ||
      c.tags.some(tag => tag.toLowerCase().includes(searchTerm))
    )
  }

  // Получение популярных коллекций
  async getPopularCollections(limit: number = 10): Promise<NFTCollection[]> {
    return Array.from(this.collections.values())
      .sort((a, b) => b.currentSupply - a.currentSupply)
      .slice(0, limit)
  }

  // Получение новых коллекций
  async getNewCollections(limit: number = 10): Promise<NFTCollection[]> {
    return Array.from(this.collections.values())
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, limit)
  }

  // Получение коллекций с высоким объемом продаж
  async getTopSellingCollections(limit: number = 10): Promise<NFTCollection[]> {
    const transactions = Array.from(this.mintTransactions.values())
    const collectionVolumes = new Map<string, number>()

    transactions.forEach(t => {
      if (t.status === 'confirmed') {
        const volume = t.price * t.quantity
        const current = collectionVolumes.get(t.collectionId) || 0
        collectionVolumes.set(t.collectionId, current + volume)
      }
    })

    return Array.from(this.collections.values())
      .sort((a, b) => {
        const volumeA = collectionVolumes.get(a.id) || 0
        const volumeB = collectionVolumes.get(b.id) || 0
        return volumeB - volumeA
      })
      .slice(0, limit)
  }
}

// Создаем экземпляр сервиса
export const nftMintingService = new NFTMintingService()

// Экспортируем полезные функции
export const createCollection = (collection: any) => 
  nftMintingService.createCollection(collection)

export const getCollection = (collectionId: string) => 
  nftMintingService.getCollection(collectionId)

export const getAllCollections = (filters?: any) => 
  nftMintingService.getAllCollections(filters)

export const mintNFT = (mintRequest: MintRequest) => 
  nftMintingService.mintNFT(mintRequest)

export const getMintTransaction = (transactionId: string) => 
  nftMintingService.getMintTransaction(transactionId)

export const getAllMintTransactions = (filters?: any) => 
  nftMintingService.getAllMintTransactions(filters)

export const getRoyalties = (nftId: string) => 
  nftMintingService.getRoyalties(nftId)

export const getAllRoyalties = (filters?: any) => 
  nftMintingService.getAllRoyalties(filters)

export const getRoyaltiesForRecipient = (recipient: string) => 
  nftMintingService.getRoyaltiesForRecipient(recipient)

export const getUnclaimedRoyalties = (recipient: string) => 
  nftMintingService.getUnclaimedRoyalties(recipient)

export const claimRoyalty = (royaltyId: string, recipient: string) => 
  nftMintingService.claimRoyalty(royaltyId, recipient)

export const getNFTStats = () => 
  nftMintingService.getNFTStats()

export const validateMetadata = (metadata: NFTMetadata) => 
  nftMintingService.validateMetadata(metadata)

export const getCollectionsByCategory = (category: string) => 
  nftMintingService.getCollectionsByCategory(category)

export const getCollectionsByTags = (tags: string[]) => 
  nftMintingService.getCollectionsByTags(tags)

export const searchNFT = (query: string) => 
  nftMintingService.searchNFT(query)

export const getPopularCollections = (limit?: number) => 
  nftMintingService.getPopularCollections(limit)

export const getNewCollections = (limit?: number) => 
  nftMintingService.getNewCollections(limit)

export const getTopSellingCollections = (limit?: number) => 
  nftMintingService.getTopSellingCollections(limit)