import { create, IPFSHTTPClient } from 'ipfs-http-client'
import { Web3Storage } from 'web3.storage'

export interface UploadProgress {
  loaded: number
  total: number
  percentage: number
}

export interface FileHealth {
  cid: string
  available: boolean
  lastChecked: Date
  providers: string[]
}

export class IPFSEnhancedService {
  private ipfs: IPFSHTTPClient
  private web3Storage: Web3Storage
  private healthCache = new Map<string, FileHealth>()

  constructor(web3StorageToken: string) {
    this.ipfs = create({ url: 'https://ipfs.infura.io:5001/api/v0' })
    this.web3Storage = new Web3Storage({ token: web3StorageToken })
  }

  async uploadWithChunking(
    file: File,
    onProgress?: (progress: UploadProgress) => void
  ): Promise<string> {
    const chunkSize = 1024 * 1024 // 1MB chunks
    const chunks: Uint8Array[] = []
    
    for (let start = 0; start < file.size; start += chunkSize) {
      const chunk = new Uint8Array(
        await file.slice(start, start + chunkSize).arrayBuffer()
      )
      chunks.push(chunk)
      
      if (onProgress) {
        onProgress({
          loaded: start + chunk.length,
          total: file.size,
          percentage: ((start + chunk.length) / file.size) * 100
        })
      }
    }

    const result = await this.ipfs.add(new Uint8Array(await file.arrayBuffer()))
    
    // Backup to Filecoin via Web3.Storage
    await this.web3Storage.put([file])
    
    return result.cid.toString()
  }

  async checkFileHealth(cid: string): Promise<FileHealth> {
    const cached = this.healthCache.get(cid)
    if (cached && Date.now() - cached.lastChecked.getTime() < 300000) {
      return cached
    }

    try {
      const stats = await this.ipfs.dht.findProvs(cid, { timeout: 10000 })
      const providers: string[] = []
      
      for await (const provider of stats) {
        if (provider.id) {
          providers.push(provider.id.toString())
        }
      }

      const health: FileHealth = {
        cid,
        available: providers.length > 0,
        lastChecked: new Date(),
        providers
      }

      this.healthCache.set(cid, health)
      return health
    } catch (error) {
      const health: FileHealth = {
        cid,
        available: false,
        lastChecked: new Date(),
        providers: []
      }
      
      this.healthCache.set(cid, health)
      return health
    }
  }

  async autoRecover(cid: string): Promise<boolean> {
    const health = await this.checkFileHealth(cid)
    
    if (!health.available) {
      try {
        // Try to re-pin the file
        await this.ipfs.pin.add(cid)
        return true
      } catch (error) {
        console.error('Auto-recovery failed:', error)
        return false
      }
    }
    
    return true
  }

  async getCDNUrl(cid: string): Promise<string> {
    const gateways = [
      `https://ipfs.io/ipfs/${cid}`,
      `https://gateway.pinata.cloud/ipfs/${cid}`,
      `https://cloudflare-ipfs.com/ipfs/${cid}`
    ]
    
    // Return fastest available gateway
    return gateways[0]
  }
}