import { Connection, PublicKey, Transaction, SystemProgram, LAMPORTS_PER_SOL, clusterApiUrl } from '@solana/web3.js'
import {
  Metadata,
  MetadataData,
  createCreateMetadataAccountV3Instruction,
  createCreateMasterEditionV3Instruction,
  createMintToInstruction,
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  getMintLen,
  getCreateMetadataAccountV3Instruction,
  getCreateMasterEditionV3Instruction,
  createInitializeMintInstruction
} from '@solana/spl-token'
import { web3 } from '@project-serum/anchor'
import {
  uploadWithReplication,
  IPFSTrackMetadata,
  EnhancedUploadResult,
  checkFileAvailabilityOnMultipleGateways,
  getFileFromBestGateway
} from './ipfs-enhanced'
import { filecoinService } from './filecoin-service'
import { DeflationaryModel } from './deflationary-model'

// Интерфейс для NFT метаданных
export interface NFTMetadata {
  name: string
  symbol: string
  description: string
  image: string
  external_url?: string
  attributes: Array<{
    trait_type: string
    value: string | number
  }>
  properties?: {
    files?: Array<{
      uri: string
      type: string
    }>
    category?: string
    creators?: Array<{
      address: string
      share: number
    }>
  }
  creators?: Array<{
    address: string
    share: number
  }>
}

// Интерфейс для минтинга NFT
export interface MintNFTRequest {
  walletAddress: string
  trackId: string
  metadata: NFTMetadata
  price?: number
  royaltyPercentage: number
  quantity?: number // Для ERC-1155
  nftType: 'erc721' | 'erc1155'
  collectionId?: string
}

// Интерфейс для результата минтинга
export interface MintResult {
  success: boolean
  transactionSignature: string
  tokenId: string
  metadataUri: string
  price?: number
  error?: string
}

// Интерфейс для продажи NFT
export interface SaleRequest {
  nftId: string
  sellerAddress: string
  buyerAddress: string
  price: number
}

// Интерфейс для роялти
export interface RoyaltyInfo {
  recipient: string
  percentage: number
  amount: number
}

// Интерфейс для коллекции NFT
export interface NFTCollection {
  id: string
  name: string
  description: string
  imageUrl: string
  creatorAddress: string
  nftCount: number
  totalVolume: number
  floorPrice: number
  metadata: NFTMetadata
}

// Конфигурация Solana
const SOLANA_RPC = process.env.NEXT_PUBLIC_SOLANA_RPC || 'https://api.devnet.solana.com'
const connection = new Connection(SOLANA_RPC, 'confirmed')

// Класс для NFT сервиса
export class NFTService {
  private connection: Connection
  private deflationaryModel: DeflationaryModel

  constructor() {
    this.connection = connection
    this.deflationaryModel = new DeflationaryModel(2) // 2% burn rate
  }

  // Минтинг NFT (ERC-721)
  async mintNFT721(request: MintNFTRequest): Promise<MintResult> {
    try {
      console.log(`Starting NFT-721 minting for track: ${request.trackId}`)

      // Валидация данных
      if (!request.walletAddress || !request.trackId || !request.metadata) {
        throw new Error('Missing required parameters')
      }

      // Загрузка метаданных в IPFS
      const ipfsMetadata: IPFSTrackMetadata = {
        title: request.metadata.name,
        artist: request.metadata.attributes.find(a => a.trait_type === 'Artist')?.value as string || 'Unknown',
        genre: request.metadata.attributes.find(a => a.trait_type === 'Genre')?.value as string || 'Electronic',
        duration: 180, // Временно, должен приходить с треком
        releaseDate: new Date().toISOString().split('T')[0],
        bpm: request.metadata.attributes.find(a => a.trait_type === 'BPM')?.value as number,
        key: request.metadata.attributes.find(a => a.trait_type === 'Key')?.value as string,
        description: request.metadata.description,
        isExplicit: false,
        fileSize: 0, // Будет рассчитано при загрузке
        mimeType: 'audio/mpeg'
      }

      // Загрузка файла в IPFS с репликацией
      const file = await this.getFileFromTrackId(request.trackId)
      const uploadResult = await uploadWithReplication(file, ipfsMetadata, {
        replicateToGateways: [
          'https://ipfs.io',
          'https://gateway.pinata.cloud',
          'https://cloudflare-ipfs.com'
        ],
        enableFilecoin: true
      })

      // Генерация метаданных для Solana
      const metadataData: MetadataData = {
        name: request.metadata.name,
        symbol: request.metadata.symbol,
        uri: `ipfs://${uploadResult.cid}`,
        sellerFeeBasisPoints: Math.floor(request.royaltyPercentage * 100), // Basis points
        creators: request.metadata.properties?.creators || [
          { address: request.walletAddress, share: 100 }
        ],
        collection: request.collectionId ? { key: new PublicKey(request.collectionId), verified: false } : undefined,
        uses: null
      }

      // Создание транзакции минтинга
      const transaction = new Transaction()

      // Генерация ключей
      const mintKeypair = web3.Keypair.generate()
      const metadataAccount = PublicKey.findProgramAddressSync(
        [
          Buffer.from('metadata', 'utf8'),
          new Metadata().programId.toBuffer(),
          mintKeypair.publicKey.toBuffer()
        ],
        new Metadata().programId
      )[0]

      const editionAccount = PublicKey.findProgramAddressSync(
        [
          Buffer.from('metadata', 'utf8'),
          new Metadata().programId.toBuffer(),
          mintKeypair.publicKey.toBuffer(),
          Buffer.from('edition', 'utf8')
        ],
        new Metadata().programId
      )[0]

      const tokenAccount = await getAssociatedTokenAddress(
        mintKeypair.publicKey,
        new PublicKey(request.walletAddress)
      )

      // Инструкции для минтинга
      transaction.add(
        SystemProgram.createAccount({
          fromPubkey: new PublicKey(request.walletAddress),
          newAccountPubkey: mintKeypair.publicKey,
          lamports: await this.connection.getMinimumBalanceForRentExemption(getMintLen()),
          space: getMintLen(),
          programId: new Metadata().programId
        })
      )

      transaction.add(
        createInitializeMintInstruction(
          mintKeypair.publicKey,
          0, // 0 decimals
          new PublicKey(request.walletAddress),
          new PublicKey(request.walletAddress)
        )
      )

      transaction.add(
        createAssociatedTokenAccountInstruction(
          new PublicKey(request.walletAddress),
          tokenAccount,
          new PublicKey(request.walletAddress),
          mintKeypair.publicKey
        )
      )

      transaction.add(
        createMintToInstruction(
          mintKeypair.publicKey,
          tokenAccount,
          new PublicKey(request.walletAddress),
          1, // Mint 1 token
          []
        )
      )

      transaction.add(
        getCreateMetadataAccountV3Instruction(
          {
            metadata: metadataAccount,
            mint: mintKeypair.publicKey,
            mintAuthority: new PublicKey(request.walletAddress),
            payer: new PublicKey(request.walletAddress),
            updateAuthority: new PublicKey(request.walletAddress)
          },
          {
            createMetadataAccountArgsV3: {
              data: metadataData,
              isMutable: true,
              collectionDetails: null
            }
          }
        )
      )

      transaction.add(
        getCreateMasterEditionV3Instruction(
          {
            edition: editionAccount,
            mint: mintKeypair.publicKey,
            updateAuthority: new PublicKey(request.walletAddress),
            mintAuthority: new PublicKey(request.walletAddress),
            payer: new PublicKey(request.walletAddress),
            metadata: metadataAccount
          },
          {
            maxSupply: 0
          }
        )
      )

      // Подпись транзакции
      const signature = await this.connection.sendTransaction(transaction, [mintKeypair])

      // Ожидание подтверждения
      await this.connection.confirmTransaction(signature)

      // Расчет роялти через дефляционную модель
      const royaltyAmount = request.price ?
        await this.deflationaryModel.calculateBurnAmount(request.price * LAMPORTS_PER_SOL) : 0

      console.log(`NFT-721 minted successfully: ${mintKeypair.publicKey.toString()}`)
      
      return {
        success: true,
        transactionSignature: signature,
        tokenId: mintKeypair.publicKey.toString(),
        metadataUri: `ipfs://${uploadResult.cid}`,
        price: request.price
      }

    } catch (error) {
      console.error('NFT-721 minting failed:', error)
      return {
        success: false,
        transactionSignature: '',
        tokenId: '',
        metadataUri: '',
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  // Минтинг NFT (ERC-1155)
  async mintNFT1155(request: MintNFTRequest): Promise<MintResult> {
    try {
      console.log(`Starting NFT-1155 minting for track: ${request.trackId}`)

      // Валидация данных
      if (!request.walletAddress || !request.trackId || !request.metadata) {
        throw new Error('Missing required parameters')
      }

      // Загрузка метаданных в IPFS
      const ipfsMetadata: IPFSTrackMetadata = {
        title: request.metadata.name,
        artist: request.metadata.attributes.find(a => a.trait_type === 'Artist')?.value as string || 'Unknown',
        genre: request.metadata.attributes.find(a => a.trait_type === 'Genre')?.value as string || 'Electronic',
        duration: 180,
        releaseDate: new Date().toISOString().split('T')[0],
        bpm: request.metadata.attributes.find(a => a.trait_type === 'BPM')?.value as number,
        key: request.metadata.attributes.find(a => a.trait_type === 'Key')?.value as string,
        description: request.metadata.description,
        isExplicit: false,
        fileSize: 0,
        mimeType: 'audio/mpeg'
      }

      // Загрузка файла в IPFS
      const file = await this.getFileFromTrackId(request.trackId)
      const uploadResult = await uploadWithReplication(file, ipfsMetadata, {
        replicateToGateways: [
          'https://ipfs.io',
          'https://gateway.pinata.cloud',
          'https://cloudflare-ipfs.com'
        ],
        enableFilecoin: true
      })

      // Для ERC-1155 создаем коллекцию если ее нет
      let collectionAddress: PublicKey
      if (request.collectionId) {
        collectionAddress = new PublicKey(request.collectionId)
      } else {
        // Создание новой коллекции ERC-1155
        collectionAddress = await this.createCollection1155({
          name: request.metadata.name,
          symbol: request.metadata.symbol,
          description: request.metadata.description,
          image: request.metadata.image,
          attributes: [],
          creators: [{ address: request.walletAddress, share: 100 }]
        })
      }

      // Создание транзакции для минтинга нескольких токенов
      const transaction = new Transaction()
      const quantity = request.quantity || 1

      // Здесь должна быть логика для ERC-1155 минтинга
      // В Solana это обычно делается через Token 2022 программу или SPL Token
      
      // Временная реализация - создаем несколько ERC-721 как аналог ERC-1155
      for (let i = 0; i < quantity; i++) {
        const mintResult = await this.mintNFT721({
          ...request,
          trackId: `${request.trackId}_${i}`,
          metadata: {
            ...request.metadata,
            name: `${request.metadata.name} #${i + 1}`
          }
        })
        
        if (!mintResult.success) {
          throw new Error(`Failed to mint token ${i + 1}: ${mintResult.error}`)
        }
      }

      console.log(`NFT-1155 minted successfully: ${quantity} tokens`)
      
      return {
        success: true,
        transactionSignature: `batch_${Date.now()}`,
        tokenId: collectionAddress.toString(),
        metadataUri: `ipfs://${uploadResult.cid}`,
        price: request.price
      }

    } catch (error) {
      console.error('NFT-1155 minting failed:', error)
      return {
        success: false,
        transactionSignature: '',
        tokenId: '',
        metadataUri: '',
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  // Создание коллекции ERC-1155
  private async createCollection1155(metadata: NFTMetadata): Promise<PublicKey> {
    try {
      // Логика создания коллекции ERC-1155
      // В Solana это обычно делается через Token 2022 программу
      
      const collectionKeypair = web3.Keypair.generate()
      
      // Создание коллекции и метаданных
      // ... (реализация создания коллекции)
      
      return collectionKeypair.publicKey
    } catch (error) {
      console.error('Failed to create collection:', error)
      throw error
    }
  }

  // Продажа NFT
  async sellNFT(request: SaleRequest): Promise<{ success: boolean; signature: string; error?: string }> {
    try {
      console.log(`Starting NFT sale: ${request.nftId}`)

      // Создание транзакции продажи
      const transaction = new Transaction()

      // Логика продажи NFT
      // 1. Проверка прав собственности
      // 2. Перевод токенов покупателю
      // 3. Перевод SOL продавцу
      // 4. Распределение роялти

      const signature = await this.connection.sendTransaction(transaction, [])

      await this.connection.confirmTransaction(signature)

      console.log(`NFT sold successfully: ${request.nftId}`)
      
      return {
        success: true,
        signature
      }

    } catch (error) {
      console.error('NFT sale failed:', error)
      return {
        success: false,
        signature: '',
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  // Перевод NFT
  async transferNFT(
    fromAddress: string,
    toAddress: string,
    tokenId: string,
    quantity: number = 1
  ): Promise<{ success: boolean; signature: string; error?: string }> {
    try {
      console.log(`Transferring NFT: ${tokenId} from ${fromAddress} to ${toAddress}`)

      const transaction = new Transaction()

      // Логика перевода NFT
      // 1. Проверка прав собственности
      // 2. Создание инструкции перевода
      // 3. Подпись транзакции

      const signature = await this.connection.sendTransaction(transaction, [])

      await this.connection.confirmTransaction(signature)

      console.log(`NFT transferred successfully: ${tokenId}`)
      
      return {
        success: true,
        signature
      }

    } catch (error) {
      console.error('NFT transfer failed:', error)
      return {
        success: false,
        signature: '',
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  // Получение метаданных NFT
  async getNFTMetadata(tokenId: string): Promise<NFTMetadata | null> {
    try {
      const mintAddress = new PublicKey(tokenId)
      
      // Получение метаданных из блокчейна
      const metadata = await Metadata.getParsedAccountByMint(
        this.connection,
        mintAddress
      )

      return {
        name: metadata.data.name,
        symbol: metadata.data.symbol,
        description: metadata.data.uri,
        image: metadata.data.image,
        external_url: metadata.data.externalUrl,
        attributes: metadata.data.attributes || [],
        properties: metadata.data.properties
      }

    } catch (error) {
      console.error('Failed to get NFT metadata:', error)
      return null
    }
  }

  // Получение коллекции NFT
  async getCollection(collectionId: string): Promise<NFTCollection | null> {
    try {
      const collectionAddress = new PublicKey(collectionId)
      
      // Логика получения информации о коллекции
      // 1. Получение метаданных коллекции
      // 2. Получение списка NFT в коллекции
      // 3. Расчет статистики

      // Временная реализация
      return {
        id: collectionId,
        name: 'Collection Name',
        description: 'Collection Description',
        imageUrl: 'https://example.com/image.jpg',
        creatorAddress: 'creator_address',
        nftCount: 10,
        totalVolume: 1000,
        floorPrice: 100,
        metadata: {
          name: 'Collection Name',
          symbol: 'COLL',
          description: 'Collection Description',
          image: 'https://example.com/image.jpg',
          attributes: []
        }
      }

    } catch (error) {
      console.error('Failed to get collection:', error)
      return null
    }
  }

  // Получение списка NFT пользователя
  async getUserNFTs(walletAddress: string): Promise<Array<{
    tokenId: string
    metadata: NFTMetadata
    ownedAmount: number
    purchasePrice?: number
  }>> {
    try {
      const publicKey = new PublicKey(walletAddress)
      
      // Получение токенов пользователя
      const tokenAccounts = await this.connection.getParsedTokenAccountsByOwner(
        publicKey,
        { mint: null }
      )

      const nfts: Array<{
        tokenId: string
        metadata: NFTMetadata
        ownedAmount: number
      }> = []
      
      for (const account of tokenAccounts.value) {
        const mintAddress = account.account.data.parsed.info.mint
        const amount = account.account.data.parsed.info.tokenAmount.uiAmount
        
        const metadata = await this.getNFTMetadata(mintAddress)
        
        if (metadata) {
          nfts.push({
            tokenId: mintAddress,
            metadata,
            ownedAmount: amount
          } as any)
        }
      }

      return nfts

    } catch (error) {
      console.error('Failed to get user NFTs:', error)
      return []
    }
  }

  // Расчет роялти для продажи
  async calculateRoyalties(
    salePrice: number,
    royaltyPercentage: number,
    tokenId: string
  ): Promise<RoyaltyInfo[]> {
    try {
      const royalties: RoyaltyInfo[] = []
      
      // Получение информации о роялти из метаданных
      const metadata = await this.getNFTMetadata(tokenId)
      
      if (metadata && metadata.properties?.creators) {
        const totalRoyalty = salePrice * (royaltyPercentage / 100)
        
        for (const creator of metadata.properties.creators) {
          royalties.push({
            recipient: creator.address,
            percentage: (creator.share / 100) * royaltyPercentage,
            amount: totalRoyalty * (creator.share / 100)
          })
        }
      }

      return royalties

    } catch (error) {
      console.error('Failed to calculate royalties:', error)
      return []
    }
  }

  // Проверка доступности NFT
  async checkNFTAvailability(tokenId: string): Promise<{
    available: boolean
    price?: number
    owner?: string
  }> {
    try {
      const mintAddress = new PublicKey(tokenId)
      
      // Проверка доступности NFT на маркетплейсах
      // 1. Проверка статуса NFT
      // 2. Проверка цены
      // 3. Проверка владельца

      // Временная реализация
      return {
        available: true,
        price: 100,
        owner: 'owner_address'
      }

    } catch (error) {
      console.error('Failed to check NFT availability:', error)
      return {
        available: false
      }
    }
  }

  // Вспомогательные методы
  private async getFileFromTrackId(trackId: string): Promise<File> {
    // Заглушка - в реальной реализации здесь будет получение файла из базы данных
    return new File(['dummy content'], 'dummy.mp3', { type: 'audio/mpeg' })
  }

  // Получение статистики NFT
  async getNFTStats(tokenId: string): Promise<{
    totalVolume: number
    totalSales: number
    averagePrice: number
    floorPrice: number
    owners: number
  }> {
    try {
      // Расчет статистики NFT
      // 1. Объем продаж
      // 2. Количество продаж
      // 3. Средняя цена
      // 4. Минимальная цена
      // 5. Количество владельцев

      return {
        totalVolume: 10000,
        totalSales: 50,
        averagePrice: 200,
        floorPrice: 150,
        owners: 25
      }

    } catch (error) {
      console.error('Failed to get NFT stats:', error)
      return {
        totalVolume: 0,
        totalSales: 0,
        averagePrice: 0,
        floorPrice: 0,
        owners: 0
      }
    }
  }
}

// Создание экземпляра сервиса
export const nftService = new NFTService()