import { Connection, PublicKey, LAMPORTS_PER_SOL } from '@solana/web3.js'
import { SPLTokenService } from './spl-token-service'

export class DevnetTest {
  private connection: Connection
  private splService: SPLTokenService

  constructor() {
    this.connection = new Connection('https://api.devnet.solana.com', 'confirmed')
    this.splService = new SPLTokenService(this.connection)
  }

  async testConnection(): Promise<boolean> {
    try {
      const version = await this.connection.getVersion()
      console.log('✅ Solana devnet connection:', version)
      return true
    } catch (error) {
      console.error('❌ Connection failed:', error)
      return false
    }
  }

  async testWalletBalance(publicKey: PublicKey): Promise<number> {
    try {
      const balance = await this.connection.getBalance(publicKey)
      const solBalance = balance / LAMPORTS_PER_SOL
      console.log(`💰 Wallet balance: ${solBalance} SOL`)
      return solBalance
    } catch (error) {
      console.error('❌ Balance check failed:', error)
      return 0
    }
  }

  async testNFTMint(publicKey: PublicKey): Promise<boolean> {
    try {
      const metadata = {
        name: 'Test Music NFT',
        symbol: 'TEST',
        description: 'Test NFT for devnet',
        image: 'https://via.placeholder.com/300',
        attributes: [{ trait_type: 'Test', value: 'Devnet' }],
        properties: {
          files: [{ uri: 'https://via.placeholder.com/300', type: 'image/png' }],
          category: 'image' as const
        }
      }

      const royalty = {
        percentage: 0.05,
        recipients: [{ address: publicKey.toBase58(), share: 100 }]
      }

      const result = await this.splService.mintMusicNFT(metadata, royalty)
      
      if (result.success) {
        console.log('✅ Test NFT minted:', result.mint?.toBase58())
        return true
      } else {
        console.error('❌ Mint failed:', result.error)
        return false
      }
    } catch (error) {
      console.error('❌ Test mint failed:', error)
      return false
    }
  }

  async runFullTest(publicKey: PublicKey): Promise<void> {
    console.log('🧪 Starting devnet tests...')
    
    const connectionOk = await this.testConnection()
    if (!connectionOk) return

    const balance = await this.testWalletBalance(publicKey)
    if (balance < 0.1) {
      console.log('⚠️ Low balance, requesting airdrop...')
      try {
        const signature = await this.connection.requestAirdrop(publicKey, 2 * LAMPORTS_PER_SOL)
        await this.connection.confirmTransaction(signature)
        console.log('✅ Airdrop completed')
      } catch (error) {
        console.error('❌ Airdrop failed:', error)
        return
      }
    }

    const mintOk = await this.testNFTMint(publicKey)
    
    console.log(mintOk ? '🎉 All tests passed!' : '❌ Some tests failed')
  }
}