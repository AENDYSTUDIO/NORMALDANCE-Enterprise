import { Filecoin } from '@glif/filecoin-wallet-provider'
import { CID } from 'multiformats/cid'
import { createHash } from 'crypto'

// Интерфейс для информации о сделке Filecoin
export interface FilecoinDeal {
  dealId: string
  minerAddress: string
  status: 'pending' | 'active' | 'failed' | 'terminated'
  size: number
  duration: number
  price: string
  createdAt: Date
  updatedAt: Date
  cid: string
}

// Интерфейс для информации о хранилище
export interface StorageInfo {
  totalSize: number
  usedSize: number
  availableSize: number
  deals: FilecoinDeal[]
  lastUpdated: Date
}

// Интерфейс для конфигурации хранилища
export interface StorageConfig {
  minerAddress: string
  defaultDuration: number // в секундах
  maxFileSize: number // в байтах
  replicationFactor: number
  pricePerGB: string
  verifiedDeals: boolean
}

// Интерфейс для прогресса загрузки
export interface UploadProgress {
  cid: string
  progress: number // 0-100
  stage: 'uploading' | 'sealing' | 'dealing' | 'completed' | 'failed'
  speed: number // bytes per second
  eta: number // estimated time in seconds
  error?: string
}

// Класс для работы с Filecoin хранилищем
export class FilecoinService {
  private filecoin: Filecoin
  private config: StorageConfig
  private activeUploads: Map<string, UploadProgress> = new Map()

  constructor(config?: Partial<StorageConfig>) {
    this.filecoin = new Filecoin({
      network: process.env.FILECOIN_NETWORK || 'calibration',
      apiEndpoint: process.env.FILECOIN_API_ENDPOINT || 'https://api.calibration.filfox.info/v1',
      walletAddress: process.env.FILECOIN_WALLET_ADDRESS
    })

    this.config = {
      minerAddress: config?.minerAddress || process.env.FILECOIN_MINER_ADDRESS || 'f0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      defaultDuration: config?.defaultDuration || 365 * 24 * 60 * 60, // 1 год
      maxFileSize: config?.maxFileSize || 100 * 1024 * 1024 * 1024, // 100GB
      replicationFactor: config?.replicationFactor || 1,
      pricePerGB: config?.pricePerGB || '0.0000001',
      verifiedDeals: config?.verifiedDeals ?? true
    }
  }

  // Основной метод загрузки файла в Filecoin
  async uploadFile(
    cid: string,
    options: {
      duration?: number
      price?: string
      replicationFactor?: number
      verified?: boolean
      minerAddress?: string
    } = {}
  ): Promise<FilecoinDeal> {
    const uploadId = this.generateUploadId()
    const progress: UploadProgress = {
      cid,
      progress: 0,
      stage: 'uploading',
      speed: 0,
      eta: 0
    }
    
    this.activeUploads.set(uploadId, progress)

    try {
      const deal = await this.createDeal(cid, {
        duration: options.duration || this.config.defaultDuration,
        price: options.price || this.calculatePrice(cid),
        replicationFactor: options.replicationFactor || this.config.replicationFactor,
        verified: options.verified ?? this.config.verifiedDeals,
        minerAddress: options.minerAddress || this.config.minerAddress
      })

      progress.progress = 100
      progress.stage = 'completed'
      progress.eta = 0

      setTimeout(() => {
        this.activeUploads.delete(uploadId)
      }, 5000)

      return deal
    } catch (error) {
      progress.stage = 'failed'
      progress.error = error instanceof Error ? error.message : 'Unknown error'
      
      setTimeout(() => {
        this.activeUploads.delete(uploadId)
      }, 10000)

      throw error
    }
  }

  // Создание сделки Filecoin
  private async createDeal(
    cid: string,
    options: {
      duration: number
      price: string
      replicationFactor: number
      verified: boolean
      minerAddress: string
    }
  ): Promise<FilecoinDeal> {
    try {
      // Создание сделки
      const deal = await this.filecoin.client.Deals.create(
        options.minerAddress,
        cid,
        {
          duration: options.duration,
          price: options.price,
          verified: options.verified
        }
      )

      return {
        dealId: deal.DealID,
        minerAddress: options.minerAddress,
        status: 'pending',
        size: await this.estimateFileSize(cid),
        duration: options.duration,
        price: options.price,
        createdAt: new Date(),
        updatedAt: new Date(),
        cid
      }
    } catch (error) {
      throw new Error(`Failed to create Filecoin deal: ${error}`)
    }
  }

  // Расчет цены за хранение
  private calculatePrice(cid: string): string {
    // Здесь можно реализовать более сложную логику ценообразования
    return this.config.pricePerGB
  }

  // Оценка размера файла по CID
  private async estimateFileSize(cid: string): Promise<number> {
    try {
      // Здесь можно запросить информацию о файле из IPFS
      // Для простоты возвращаем заглушку
      return 1024 * 1024 // 1MB
    } catch {
      return 1024 * 1024 // 1MB fallback
    }
  }

  // Получение информации о сделке
  async getDeal(dealId: string): Promise<FilecoinDeal | null> {
    try {
      const deal = await this.filecoin.client.Deals.get(dealId)
      
      return {
        dealId,
        minerAddress: deal.Miner,
        status: this.mapDealStatus(deal.State),
        size: deal.Size,
        duration: deal.Duration,
        price: deal.Price,
        createdAt: new Date(deal.StartEpoch * 1000),
        updatedAt: new Date(),
        cid: deal.PayloadCID
      }
    } catch {
      return null
    }
  }

  // Получение всех сделок пользователя
  async getAllDeals(): Promise<FilecoinDeal[]> {
    try {
      const deals = await this.filecoin.client.Deals.list()
      
      return deals.map(deal => ({
        dealId: deal.DealID,
        minerAddress: deal.Miner,
        status: this.mapDealStatus(deal.State),
        size: deal.Size,
        duration: deal.Duration,
        price: deal.Price,
        createdAt: new Date(deal.StartEpoch * 1000),
        updatedAt: new Date(),
        cid: deal.PayloadCID
      }))
    } catch {
      return []
    }
  }

  // Отмена сделки
  async cancelDeal(dealId: string): Promise<boolean> {
    try {
      await this.filecoin.client.Deals.terminate(dealId)
      return true
    } catch {
      return false
    }
  }

  // Обновление статуса сделки
  async updateDealStatus(dealId: string): Promise<FilecoinDeal | null> {
    const deal = await this.getDeal(dealId)
    if (!deal) return null

    // Проверяем, изменился ли статус
    const currentDeal = await this.getDeal(dealId)
    if (currentDeal && currentDeal.status !== deal.status) {
      return currentDeal
    }

    return deal
  }

  // Получение информации о хранилище
  async getStorageInfo(): Promise<StorageInfo> {
    const deals = await this.getAllDeals()
    const totalSize = deals.reduce((sum, deal) => sum + deal.size, 0)
    
    return {
      totalSize: this.config.maxFileSize,
      usedSize: totalSize,
      availableSize: this.config.maxFileSize - totalSize,
      deals,
      lastUpdated: new Date()
    }
  }

  // Проверка доступности файла
  async checkFileAvailability(cid: string): Promise<{
    available: boolean
    deals: FilecoinDeal[]
    fastestDeal?: FilecoinDeal
  }> {
    const deals = await this.getAllDeals()
    const fileDeals = deals.filter(deal => deal.cid === cid)
    
    if (fileDeals.length === 0) {
      return {
        available: false,
        deals: []
      }
    }

    // Находим самую быструю сделку
    const activeDeals = fileDeals.filter(deal => deal.status === 'active')
    const fastestDeal = activeDeals.length > 0 
      ? activeDeals.reduce((fastest, current) => 
          current.createdAt < fastest.createdAt ? current : fastest
        )
      : undefined

    return {
      available: activeDeals.length > 0,
      deals: fileDeals,
      fastestDeal
    }
  }

  // Восстановление недоступного файла
  async restoreFile(cid: string): Promise<{
    success: boolean
    restoredDeals: FilecoinDeal[]
    actions: string[]
  }> {
    const actions: string[] = []
    const restoredDeals: FilecoinDeal[] = []

    try {
      const availability = await this.checkFileAvailability(cid)
      
      if (!availability.available) {
        actions.push('File not available on Filecoin')
        
        // Создаем новую сделку
        const deal = await this.uploadFile(cid, {
          duration: this.config.defaultDuration,
          price: this.calculatePrice(cid),
          replicationFactor: this.config.replicationFactor,
          verified: this.config.verifiedDeals
        })
        
        restoredDeals.push(deal)
        actions.push(`Created new deal: ${deal.dealId}`)
      } else {
        actions.push('File already available')
      }

      return {
        success: true,
        restoredDeals,
        actions
      }
    } catch (error) {
      return {
        success: false,
        restoredDeals: [],
        actions: [`Failed to restore file: ${error}`]
      }
    }
  }

  // Мониторинг сделок
  async monitorDeals(): Promise<{
    activeDeals: FilecoinDeal[]
    pendingDeals: FilecoinDeal[]
    failedDeals: FilecoinDeal[]
    totalSize: number
  }> {
    const deals = await this.getAllDeals()
    
    const activeDeals = deals.filter(deal => deal.status === 'active')
    const pendingDeals = deals.filter(deal => deal.status === 'pending')
    const failedDeals = deals.filter(deal => deal.status === 'failed')
    
    const totalSize = deals.reduce((sum, deal) => sum + deal.size, 0)

    return {
      activeDeals,
      pendingDeals,
      failedDeals,
      totalSize
    }
  }

  // Расчет стоимости хранения
  calculateStorageCost(
    sizeInGB: number,
    durationInDays: number,
    pricePerGB: string = this.config.pricePerGB
  ): string {
    const pricePerDay = parseFloat(pricePerGB) / 365
    const totalCost = sizeInGB * durationInDays * pricePerDay
    
    return totalCost.toFixed(9)
  }

  // Получение прогресса загрузки
  getUploadProgress(cid: string): UploadProgress | null {
    for (const [uploadId, progress] of this.activeUploads) {
      if (progress.cid === cid) {
        return progress
      }
    }
    return null
  }

  // Получение всех активных загрузок
  getActiveUploads(): UploadProgress[] {
    return Array.from(this.activeUploads.values())
  }

  // Отмена загрузки
  cancelUpload(cid: string): boolean {
    for (const [uploadId, progress] of this.activeUploads) {
      if (progress.cid === cid) {
        progress.stage = 'failed'
        progress.error = 'Upload cancelled by user'
        this.activeUploads.delete(uploadId)
        return true
      }
    }
    return false
  }

  // Генерация уникального ID для загрузки
  private generateUploadId(): string {
    return `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  // Отображение статуса сделки
  private mapDealStatus(status: string): FilecoinDeal['status'] {
    switch (status) {
      case 'StorageDealActive':
        return 'active'
      case 'StorageDealAccepted':
      case 'StorageDealPublished':
        return 'pending'
      case 'StorageDealFailed':
        return 'failed'
      case 'StorageDealTerminated':
        return 'terminated'
      default:
        return 'pending'
    }
  }

  // Проверка здоровья файлов
  async checkFileHealth(cid: string): Promise<{
    healthy: boolean
    deals: FilecoinDeal[]
    issues: string[]
    recommendations: string[]
  }> {
    const issues: string[] = []
    const recommendations: string[] = []
    const deals = await this.getAllDeals()
    const fileDeals = deals.filter(deal => deal.cid === cid)
    
    if (fileDeals.length === 0) {
      issues.push('No Filecoin deals found for this file')
      recommendations.push('Create a new Filecoin deal for this file')
    }

    const activeDeals = fileDeals.filter(deal => deal.status === 'active')
    if (activeDeals.length === 0) {
      issues.push('No active deals found')
      recommendations.push('Create new active deals')
    }

    // Проверка репликации
    if (activeDeals.length < this.config.replicationFactor) {
      issues.push(`Insufficient replication factor: ${activeDeals.length}/${this.config.replicationFactor}`)
      recommendations.push(`Create additional deals to meet replication factor`)
    }

    // Проверка срока действия сделок
    const expiringSoon = activeDeals.filter(deal => {
      const expiryDate = new Date(deal.createdAt.getTime() + deal.duration * 1000)
      const daysUntilExpiry = (expiryDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
      return daysUntilExpiry < 30
    })

    if (expiringSoon.length > 0) {
      issues.push(`${expiringSoon.length} deals expiring soon`)
      recommendations.push('Renew expiring deals')
    }

    return {
      healthy: issues.length === 0,
      deals: fileDeals,
      issues,
      recommendations
    }
  }

  // Автоматическое продление сделок
  async autoRenewDeals(): Promise<{
    renewedDeals: FilecoinDeal[]
    failedDeals: string[]
    recommendations: string[]
  }> {
    const renewedDeals: FilecoinDeal[] = []
    const failedDeals: string[] = []
    const recommendations: string[] = []

    try {
      const deals = await this.getAllDeals()
      const activeDeals = deals.filter(deal => deal.status === 'active')
      
      for (const deal of activeDeals) {
        const expiryDate = new Date(deal.createdAt.getTime() + deal.duration * 1000)
        const daysUntilExpiry = (expiryDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
        
        if (daysUntilExpiry < 7) { // Продление за неделю до истечения
          try {
            const newDeal = await this.uploadFile(deal.cid, {
              duration: this.config.defaultDuration,
              price: this.calculatePrice(deal.cid),
              replicationFactor: this.config.replicationFactor,
              verified: this.config.verifiedDeals
            })
            renewedDeals.push(newDeal)
          } catch (error) {
            failedDeals.push(deal.dealId)
            recommendations.push(`Failed to renew deal ${deal.dealId}: ${error}`)
          }
        }
      }

      return {
        renewedDeals,
        failedDeals,
        recommendations
      }
    } catch (error) {
      return {
        renewedDeals: [],
        failedDeals: [],
        recommendations: [`Auto-renewal failed: ${error}`]
      }
    }
  }
}

// Создаем экземпляр сервиса
export const filecoinService = new FilecoinService()

// Экспортируем полезные функции
export const uploadFileToStorage = (cid: string, options?: any) => 
  filecoinService.uploadFile(cid, options)

export const getFilecoinDeal = (dealId: string) => 
  filecoinService.getDeal(dealId)

export const getAllFilecoinDeals = () => 
  filecoinService.getAllDeals()

export const checkFilecoinAvailability = (cid: string) => 
  filecoinService.checkFileAvailability(cid)

export const restoreFilecoinFile = (cid: string) => 
  filecoinService.restoreFile(cid)

export const getStorageInfo = () => 
  filecoinService.getStorageInfo()

export const monitorFilecoinDeals = () => 
  filecoinService.monitorDeals()

export const calculateStorageCost = (sizeInGB: number, durationInDays: number, pricePerGB?: string) => 
  filecoinService.calculateStorageCost(sizeInGB, durationInDays, pricePerGB)

export const checkFilecoinHealth = (cid: string) => 
  filecoinService.checkFileHealth(cid)

export const autoRenewFilecoinDeals = () => 
  filecoinService.autoRenewDeals()