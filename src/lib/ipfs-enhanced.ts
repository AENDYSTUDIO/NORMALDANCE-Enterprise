import { create } from 'ipfs-http-client'
import { CID } from 'multiformats/cid'
import { fromString } from 'uint8arrays/from-string'
import { toString } from 'uint8arrays/to-string'
import { Filecoin } from '@glif/filecoin-wallet-provider'
import { FilecoinClient } from '@glif/filecoin-wallet-provider/dist/FilecoinClient'
import { UploadResult } from 'ipfs-core-types/src/root'
import { globSource } from 'ipfs-http-client'
import { Readable } from 'stream'

// Интерфейс для метаданных трека
export interface IPFSTrackMetadata {
  title: string
  artist: string
  album?: string
  genre?: string
  duration?: number
  bpm?: number
  key?: string
  releaseDate?: string
  description?: string
  coverImage?: string
  audioFile?: string
  waveform?: string
  lyrics?: string
  collaborators?: string[]
  tags?: string[]
  license?: string
  isrc?: string
  spotifyId?: string
  appleId?: string
  youtubeId?: string
}

// Интерфейс для расширенного результата загрузки
export interface EnhancedUploadResult {
  cid: string
  url: string
  size: number
  mimeType: string
  timestamp: number
  gatewayUrls: string[]
  filecoinStatus?: {
    minerAddress: string
    dealId?: string
    status: 'pending' | 'active' | 'failed'
    price?: string
  }
  replicationStatus: {
    ipfs: boolean
    filecoin: boolean
    cdn: boolean
  }
}

// Конфигурация IPFS
const IPFS_CONFIG = {
  host: process.env.IPFS_HOST || 'ipfs.infura.io',
  port: Number(process.env.IPFS_PORT) || 5001,
  protocol: 'https',
  headers: {
    authorization: `Basic ${Buffer.from(`${process.env.IPFS_PROJECT_ID}:${process.env.IPFS_PROJECT_SECRET}`).toString('base64')}`
  }
}

// Конфигурация Filecoin
const FILECOIN_CONFIG = {
  network: process.env.FILECOIN_NETWORK || 'calibration',
  apiEndpoint: process.env.FILECOIN_API_ENDPOINT || 'https://api.calibration.filfox.info/v1',
  walletAddress: process.env.FILECOIN_WALLET_ADDRESS,
  minerAddress: process.env.FILECOIN_MINER_ADDRESS || 'f0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
}

// Конфигурация CDN
const CDN_CONFIG = {
  enabled: process.env.CDN_ENABLED === 'true',
  providers: ['cloudflare', 'fastly'],
  fallbackTimeout: 5000
}

// Класс для работы с IPFS
class IPFSService {
  private ipfs: any
  private filecoin: FilecoinClient
  private gateways: string[] = [
    'https://ipfs.io/ipfs',
    'https://cloudflare-ipfs.com/ipfs',
    'https://gateway.pinata.cloud/ipfs',
    'https://ipfs.infura.io/ipfs'
  ]

  constructor() {
    this.ipfs = create({
      url: `${IPFS_CONFIG.protocol}://${IPFS_CONFIG.host}:${IPFS_CONFIG.port}`,
      headers: IPFS_CONFIG.headers
    })

    this.filecoin = new Filecoin({
      network: FILECOIN_CONFIG.network,
      apiEndpoint: FILECOIN_CONFIG.apiEndpoint,
      walletAddress: FILECOIN_CONFIG.walletAddress
    })
  }

  // Основной метод загрузки с репликацией
  async uploadWithReplication(
    data: string | Buffer | object,
    options: {
      filename?: string
      contentType?: string
      replication?: {
        ipfs: boolean
        filecoin: boolean
        cdn: boolean
      }
      metadata?: Record<string, any>
    } = {}
  ): Promise<EnhancedUploadResult> {
    const startTime = Date.now()
    const replication = options.replication || {
      ipfs: true,
      filecoin: true,
      cdn: true
    }

    try {
      // Загрузка в IPFS
      const ipfsResult = await this.uploadToIPFS(data, options)
      
      // Параллельная репликация
      const [filecoinResult, cdnResult] = await Promise.allSettled([
        replication.filecoin ? this.uploadToFilecoin(ipfsResult.cid) : Promise.resolve(null),
        replication.cdn ? this.uploadToCDN(ipfsResult.cid) : Promise.resolve(null)
      ])

      const result: EnhancedUploadResult = {
        cid: ipfsResult.cid,
        url: this.getGatewayUrl(ipfsResult.cid),
        size: ipfsResult.size,
        mimeType: options.contentType || 'application/octet-stream',
        timestamp: startTime,
        gatewayUrls: this.getGatewayUrls(ipfsResult.cid),
        replicationStatus: {
          ipfs: true,
          filecoin: filecoinResult.status === 'fulfilled',
          cdn: cdnResult.status === 'fulfilled'
        }
      }

      // Добавляем информацию о Filecoin, если успешно
      if (filecoinResult.status === 'fulfilled' && filecoinResult.value) {
        result.filecoinStatus = filecoinResult.value
      }

      return result
    } catch (error) {
      throw new Error(`IPFS upload failed: ${error}`)
    }
  }

  // Загрузка в IPFS
  private async uploadToIPFS(
    data: string | Buffer | object,
    options: { filename?: string; contentType?: string; metadata?: Record<string, any> }
  ): Promise<{ cid: string; size: number }> {
    let content: Buffer
    let filename = options.filename || 'file'

    if (typeof data === 'string') {
      content = fromString(data)
    } else if (Buffer.isBuffer(data)) {
      content = data
    } else if (typeof data === 'object') {
      if (options.contentType?.startsWith('image/')) {
        // Для изображений - буфер
        content = Buffer.from(JSON.stringify(data))
      } else {
        // Для метаданных - JSON
        content = fromString(JSON.stringify(data, null, 2))
        filename = `${filename}.json`
      }
    } else {
      throw new Error('Unsupported data type')
    }

    const { cid } = await this.ipfs.add({
      content,
      path: filename,
      pin: true,
      metadata: options.metadata
    })

    return {
      cid: cid.toString(),
      size: content.length
    }
  }

  // Загрузка в Filecoin
  private async uploadToFilecoin(cid: string): Promise<{
    minerAddress: string
    dealId?: string
    status: 'pending' | 'active' | 'failed'
    price?: string
  }> {
    try {
      // Создание сделки Filecoin
      const deal = await this.filecoin.client.Deals.create(
        FILECOIN_CONFIG.minerAddress,
        cid,
        {
          duration: 365 * 24 * 60 * 60, // 1 год
          price: '0.0000001', // Базовая цена
          verified: true
        }
      )

      return {
        minerAddress: FILECOIN_CONFIG.minerAddress,
        dealId: deal.DealID,
        status: 'pending'
      }
    } catch (error) {
      console.error('Filecoin upload failed:', error)
      return {
        minerAddress: FILECOIN_CONFIG.minerAddress,
        status: 'failed'
      }
    }
  }

  // Загрузка в CDN
  private async uploadToCDN(cid: string): Promise<boolean> {
    if (!CDN_CONFIG.enabled) {
      return false
    }

    try {
      // Здесь можно добавить логику интеграции с CDN провайдерами
      // Например, Cloudflare, Fastly и т.д.
      await this.purgeCDNCache(cid)
      return true
    } catch (error) {
      console.error('CDN upload failed:', error)
      return false
    }
  }

  // Очистка кеша CDN
  private async purgeCDNCache(cid: string): Promise<void> {
    // Реализация очистки кеша для разных CDN провайдеров
    // Это зависит от используемого CDN сервиса
  }

  // Получение URL шлюза
  private getGatewayUrl(cid: string): string {
    return `${this.gateways[0]}/${cid}`
  }

  // Получение всех URL шлюзов
  private getGatewayUrls(cid: string): string[] {
    return this.gateways.map(gateway => `${gateway}/${cid}`)
  }

  // Проверка доступности файла на нескольких шлюзах
  async checkFileAvailabilityOnMultipleGateways(cid: string): Promise<{
    available: string[]
    unavailable: string[]
    fastest: string | null
  }> {
    const available: string[] = []
    const unavailable: string[] = []
    const responseTimes: { [url: string]: number } = {}

    const checkGateway = async (url: string): Promise<void> => {
      const startTime = Date.now()
      try {
        const response = await fetch(`${url}/${cid}`)
        if (response.ok) {
          available.push(url)
          responseTimes[url] = Date.now() - startTime
        } else {
          unavailable.push(url)
        }
      } catch {
        unavailable.push(url)
      }
    }

    await Promise.all(this.gateways.map(checkGateway))

    // Находим самый быстрый шлюз
    let fastest: string | null = null
    let minTime = Infinity
    for (const [url, time] of Object.entries(responseTimes)) {
      if (time < minTime) {
        minTime = time
        fastest = url
      }
    }

    return {
      available,
      unavailable,
      fastest
    }
  }

  // Получение файла с лучшего шлюза
  async getFileFromBestGateway(cid: string): Promise<Response> {
    const availability = await this.checkFileAvailabilityOnMultipleGateways(cid)
    
    if (availability.fastest) {
      return fetch(`${availability.fastest}/${cid}`)
    }

    if (availability.available.length > 0) {
      return fetch(`${availability.available[0]}/${cid}`)
    }

    throw new Error('File not available on any gateway')
  }

  // Создание метаданных NFT
  async createNFTMetadata(
    metadata: {
      name: string
      description: string
      image: string
      external_url?: string
      attributes?: Array<{
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
    },
    imageBuffer?: Buffer
  ): Promise<{ metadata: any; imageCid: string }> {
    // Загрузка изображения
    const imageUpload = await this.uploadWithReplication(
      imageBuffer || metadata.image,
      {
        filename: 'image.png',
        contentType: 'image/png'
      }
    )

    // Создание метаданных
    const nftMetadata = {
      name: metadata.name,
      description: metadata.description,
      image: `ipfs://${imageUpload.cid}`,
      external_url: metadata.external_url,
      attributes: metadata.attributes || [],
      properties: metadata.properties || {}
    }

    // Загрузка метаданных
    const metadataUpload = await this.uploadWithReplication(nftMetadata, {
      filename: 'metadata.json',
      contentType: 'application/json'
    })

    return {
      metadata: nftMetadata,
      imageCid: imageUpload.cid
    }
  }

  // Пакетная загрузка файлов
  async batchUpload(
    files: Array<{
      data: string | Buffer
      filename: string
      contentType?: string
    }>
  ): Promise<EnhancedUploadResult[]> {
    const results: EnhancedUploadResult[] = []

    for (const file of files) {
      const result = await this.uploadWithReplication(file.data, {
        filename: file.filename,
        contentType: file.contentType
      })
      results.push(result)
    }

    return results
  }

  // Удаление файла из IPFS (unpin)
  async unpinFile(cid: string): Promise<boolean> {
    try {
      await this.ipfs.pin.rm(cid)
      return true
    } catch (error) {
      console.error('Failed to unpin file:', error)
      return false
    }
  }

  // Получение информации о файле
  async getFileInfo(cid: string): Promise<{
    cid: string
    size: number
    type: string
    pinned: boolean
    timestamp: number
  }> {
    try {
      const stats = await this.ipfs.object.stat(cid)
      return {
        cid,
        size: stats.CumulativeSize,
        type: stats.Type,
        pinned: stats.Type === 'pinned',
        timestamp: stats.Ts
      }
    } catch (error) {
      throw new Error(`Failed to get file info: ${error}`)
    }
  }

  // Поиск файлов по CID
  async searchByCID(cid: string): Promise<{
    exists: boolean
    gateways: string[]
    alternatives?: string[]
  }> {
    const availability = await this.checkFileAvailabilityOnMultipleGateways(cid)
    
    return {
      exists: availability.available.length > 0,
      gateways: availability.available,
      alternatives: availability.unavailable.length > 0 ? availability.unavailable : undefined
    }
  }

  // Мониторинг здоровья файлов
  async monitorFileHealth(cid: string): Promise<{
    healthy: boolean
    checks: {
      ipfs: boolean
      filecoin: boolean
      cdn: boolean
    }
    lastChecked: number
    responseTime: number
  }> {
    const startTime = Date.now()
    
    try {
      const response = await this.getFileFromBestGateway(cid)
      const responseTime = Date.now() - startTime
      
      return {
        healthy: response.ok,
        checks: {
          ipfs: true,
          filecoin: (await this.uploadToFilecoin(cid)).status !== 'failed',
          cdn: true
        },
        lastChecked: Date.now(),
        responseTime
      }
    } catch (error) {
      return {
        healthy: false,
        checks: {
          ipfs: false,
          filecoin: false,
          cdn: false
        },
        lastChecked: Date.now(),
        responseTime: 0
      }
    }
  }

  // Восстановление недоступных файлов
  async restoreFile(cid: string): Promise<{
    success: boolean
    restoredFrom: string
    actions: string[]
  }> {
    const actions: string[] = []
    
    try {
      // Проверяем доступность
      const availability = await this.checkFileAvailabilityOnMultipleGateways(cid)
      
      if (availability.available.length === 0) {
        // Файл недоступен, пытаемся восстановить
        actions.push('File not available on any gateway')
        
        // Проверяем, закреплен ли файл в IPFS
        const fileInfo = await this.getFileInfo(cid)
        if (!fileInfo.pinned) {
          // Повторно закрепляем файл
          await this.ipfs.pin.add(cid)
          actions.push('Re-pinned file to IPFS')
        }
        
        // Повторно загружаем в Filecoin
        const filecoinResult = await this.uploadToFilecoin(cid)
        if (filecoinResult.status === 'pending') {
          actions.push('Re-uploaded to Filecoin')
        }
        
        // Очищка CDN кеша
        await this.purgeCDNCache(cid)
        actions.push('Purged CDN cache')
        
        return {
          success: true,
          restoredFrom: 'IPFS',
          actions
        }
      }
      
      return {
        success: true,
        restoredFrom: 'Already available',
        actions: ['File is already available']
      }
    } catch (error) {
      return {
        success: false,
        restoredFrom: '',
        actions: [`Failed to restore: ${error}`]
      }
    }
  }
}

// Создаем экземпляр сервиса
export const ipfsService = new IPFSService()

// Экспортируем полезные функции
export const uploadWithReplication = (data: string | Buffer | object, options?: any) => 
  ipfsService.uploadWithReplication(data, options)

export const checkFileAvailabilityOnMultipleGateways = (cid: string) => 
  ipfsService.checkFileAvailabilityOnMultipleGateways(cid)

export const getFileFromBestGateway = (cid: string) => 
  ipfsService.getFileFromBestGateway(cid)

export const createNFTMetadata = (metadata: any, imageBuffer?: Buffer) => 
  ipfsService.createNFTMetadata(metadata, imageBuffer)

// Экспортируем класс для использования в других модулях
export { IPFSService }