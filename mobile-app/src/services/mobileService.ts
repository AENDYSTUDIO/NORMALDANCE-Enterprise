// Сервис для мобильного приложения NormalDance
import { Audio } from 'expo-av'
import * as FileSystem from 'expo-file-system'
import { Connection, PublicKey, Transaction } from '@solana/web3.js'
import { AnchorProvider, Program, web3 } from '@coral-xyz/anchor'

// Конфигурация
const SOLANA_NETWORK = 'devnet'
const RPC_URL = 'https://api.devnet.solana.com'
const API_BASE_URL = 'https://api.normaldance.com'

// Интерфейсы
export interface MobileTrack {
  id: string
  title: string
  artist: string
  genre: string
  duration: number
  ipfsHash: string
  metadata: {
    title: string
    artist: string
    genre: string
    duration: number
    albumArt?: string
    description?: string
    releaseDate: string
    bpm?: number
    key?: string
    isExplicit: boolean
    fileSize: number
    mimeType: string
  }
  price?: number
  isExplicit: boolean
  playCount: number
  likeCount: number
}

export interface WalletState {
  connected: boolean
  publicKey?: string
  balance?: number
}

export interface StakingInfo {
  level: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM'
  amountStaked: number
  apy: number
  lockPeriod: number
  rewards: number
}

export interface UploadProgress {
  progress: number
  status: 'uploading' | 'processing' | 'completed' | 'failed'
  error?: string
}

export class MobileService {
  private connection: Connection
  private sound: Audio.Sound | null = null

  constructor() {
    this.connection = new Connection(RPC_URL, 'confirmed')
  }

  // Работа с треками
  async loadTracks(): Promise<MobileTrack[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/tracks`)
      const data = await response.json()
      
      if (data.success) {
        return data.data.map((track: any) => ({
          id: track.id,
          title: track.title,
          artist: track.artistName,
          genre: track.genre,
          duration: track.duration,
          ipfsHash: track.ipfsHash,
          metadata: track.metadata,
          price: track.price,
          isExplicit: track.isExplicit,
          playCount: track.playCount,
          likeCount: track.likeCount
        }))
      }
      return []
    } catch (error) {
      console.error('Failed to load tracks:', error)
      return []
    }
  }

  async searchTracks(query: string): Promise<MobileTrack[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/tracks/search?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      
      if (data.success) {
        return data.data.map((track: any) => ({
          id: track.id,
          title: track.title,
          artist: track.artistName,
          genre: track.genre,
          duration: track.duration,
          ipfsHash: track.ipfsHash,
          metadata: track.metadata,
          price: track.price,
          isExplicit: track.isExplicit,
          playCount: track.playCount,
          likeCount: track.likeCount
        }))
      }
      return []
    } catch (error) {
      console.error('Failed to search tracks:', error)
      return []
    }
  }

  async getTrackById(id: string): Promise<MobileTrack | null> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/tracks/${id}`)
      const data = await response.json()
      
      if (data.success) {
        const track = data.data
        return {
          id: track.id,
          title: track.title,
          artist: track.artistName,
          genre: track.genre,
          duration: track.duration,
          ipfsHash: track.ipfsHash,
          metadata: track.metadata,
          price: track.price,
          isExplicit: track.isExplicit,
          playCount: track.playCount,
          likeCount: track.likeCount
        }
      }
      return null
    } catch (error) {
      console.error('Failed to get track:', error)
      return null
    }
  }

  // Работа с аудио
  async playTrack(track: MobileTrack): Promise<void> {
    try {
      // Остановка текущего трека
      if (this.sound) {
        await this.sound.unloadAsync()
      }

      // Загрузка аудио из IPFS
      const audioUrl = `https://gateway.pinata.cloud/ipfs/${track.ipfsHash}`
      const { sound: newSound } = await Audio.Sound.createAsync(
        { uri: audioUrl },
        { shouldPlay: true }
      )

      this.sound = newSound

      // Обновление счетчика воспроизведений
      await fetch(`${API_BASE_URL}/api/tracks/${track.id}/play`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })

    } catch (error) {
      console.error('Failed to play track:', error)
      throw error
    }
  }

  async pausePlayback(): Promise<void> {
    if (this.sound) {
      await this.sound.pauseAsync()
    }
  }

  async resumePlayback(): Promise<void> {
    if (this.sound) {
      await this.sound.playAsync()
    }
  }

  async stopPlayback(): Promise<void> {
    if (this.sound) {
      await this.sound.stopAsync()
      await this.sound.unloadAsync()
      this.sound = null
    }
  }

  // Работа с кошельком
  async connectWallet(): Promise<WalletState> {
    try {
      // Здесь должна быть интеграция с мобильным кошельком
      // Пока используем заглушку
      const mockPublicKey = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU'
      const balance = await this.connection.getBalance(new PublicKey(mockPublicKey))
      
      return {
        connected: true,
        publicKey: mockPublicKey,
        balance: balance / 1e9 // SOL to lamports
      }
    } catch (error) {
      console.error('Failed to connect wallet:', error)
      throw error
    }
  }

  async disconnectWallet(): Promise<void> {
    // Логика отключения кошелька
    console.log('Wallet disconnected')
  }

  async getWalletBalance(publicKey: string): Promise<number> {
    try {
      const balance = await this.connection.getBalance(new PublicKey(publicKey))
      return balance / 1e9 // SOL to lamports
    } catch (error) {
      console.error('Failed to get wallet balance:', error)
      return 0
    }
  }

  // Работа с лайками
  async likeTrack(trackId: string, walletAddress: string): Promise<void> {
    try {
      await fetch(`${API_BASE_URL}/api/tracks/${trackId}/like`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ walletAddress })
      })
    } catch (error) {
      console.error('Failed to like track:', error)
      throw error
    }
  }

  async unlikeTrack(trackId: string, walletAddress: string): Promise<void> {
    try {
      await fetch(`${API_BASE_URL}/api/tracks/${trackId}/unlike`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ walletAddress })
      })
    } catch (error) {
      console.error('Failed to unlike track:', error)
      throw error
    }
  }

  // Работа со стейкингом
  async getStakingInfo(walletAddress: string): Promise<StakingInfo | null> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/staking/info?walletAddress=${walletAddress}`)
      const data = await response.json()
      
      if (data.success) {
        return {
          level: data.data.level,
          amountStaked: data.data.amountStaked,
          apy: data.data.apy,
          lockPeriod: data.data.lockPeriod,
          rewards: data.data.rewards
        }
      }
      return null
    } catch (error) {
      console.error('Failed to get staking info:', error)
      return null
    }
  }

  async stakeTokens(amount: number, lockPeriod: number): Promise<string> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/staking/stake`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ amount, lockPeriod })
      })
      
      const data = await response.json()
      if (data.success) {
        return data.data.signature
      }
      throw new Error(data.error || 'Staking failed')
    } catch (error) {
      console.error('Failed to stake tokens:', error)
      throw error
    }
  }

  async unstakeTokens(): Promise<string> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/staking/unstake`, {
        method: 'POST'
      })
      
      const data = await response.json()
      if (data.success) {
        return data.data.signature
      }
      throw new Error(data.error || 'Unstaking failed')
    } catch (error) {
      console.error('Failed to unstake tokens:', error)
      throw error
    }
  }

  // Загрузка треков
  async uploadTrack(
    file: { uri: string; name: string; type: string },
    metadata: {
      title: string
      artist: string
      genre: string
      description?: string
      isExplicit: boolean
    },
    onProgress: (progress: UploadProgress) => void
  ): Promise<string> {
    try {
      // Чтение файла
      const fileContent = await FileSystem.readAsStringAsync(file.uri, {
        encoding: FileSystem.EncodingType.Base64
      })

      // Создание FormData
      const formData = new FormData()
      formData.append('file', {
        uri: file.uri,
        name: file.name,
        type: file.type
      } as any)
      
      formData.append('metadata', JSON.stringify(metadata))

      // Отправка файла
      const response = await fetch(`${API_BASE_URL}/api/tracks/upload`, {
        method: 'POST',
        body: formData,
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      })

      const data = await response.json()
      if (data.success) {
        return data.data.trackId
      }
      throw new Error(data.error || 'Upload failed')
    } catch (error) {
      console.error('Failed to upload track:', error)
      throw error
    }
  }

  // Работа с профилем
  async getUserProfile(walletAddress: string): Promise<any> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/users/profile?walletAddress=${walletAddress}`)
      const data = await response.json()
      
      if (data.success) {
        return data.data
      }
      return null
    } catch (error) {
      console.error('Failed to get user profile:', error)
      return null
    }
  }

  async updateUserProfile(walletAddress: string, profileData: any): Promise<boolean> {
    try {
      const response = await fetch(`${API_BASE_URL}/api/users/profile`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ walletAddress, ...profileData })
      })
      
      const data = await response.json()
      return data.success
    } catch (error) {
      console.error('Failed to update user profile:', error)
      return false
    }
  }

  // Очистка ресурсов
  cleanup(): void {
    if (this.sound) {
      this.sound.unloadAsync()
      this.sound = null
    }
  }
}

// Создание экземпляра сервиса
export const mobileService = new MobileService()