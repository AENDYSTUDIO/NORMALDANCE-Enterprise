import { Connection, PublicKey, Transaction, SystemProgram, LAMPORTS_PER_SOL, Keypair } from '@solana/web3.js'
import { createMint, getOrCreateAssociatedTokenAccount, mintTo, TOKEN_PROGRAM_ID } from '@solana/spl-token'
import { Metaplex, keypairIdentity, bundlrStorage } from '@metaplex-foundation/js'

const connection = new Connection('https://api.devnet.solana.com', 'confirmed')

export class Web3Service {
  private metaplex: Metaplex

  constructor() {
    this.metaplex = Metaplex.make(connection)
      .use(bundlrStorage())
  }

  async mintTrackNFT(
    walletAddress: string,
    metadata: {
      name: string
      symbol: string
      description: string
      image: string
      attributes: Array<{ trait_type: string; value: string }>
    }
  ): Promise<string> {
    try {
      const { nft } = await this.metaplex.nfts().create({
        uri: await this.uploadMetadata(metadata),
        name: metadata.name,
        symbol: metadata.symbol,
        sellerFeeBasisPoints: 500, // 5%
        creators: [
          {
            address: new PublicKey(walletAddress),
            share: 100,
          },
        ],
      })

      return nft.address.toString()
    } catch (error) {
      console.error('NFT minting failed:', error)
      throw new Error('Failed to mint NFT')
    }
  }

  async createStakingPool(
    authority: string,
    rewardRate: number,
    lockPeriod: number
  ): Promise<string> {
    try {
      // Создание токена для стейкинга
      const mint = await createMint(
        connection,
        Keypair.generate(), // payer
        new PublicKey(authority), // mint authority
        null, // freeze authority
        9 // decimals
      )

      return mint.toString()
    } catch (error) {
      console.error('Staking pool creation failed:', error)
      throw new Error('Failed to create staking pool')
    }
  }

  async getBalance(address: string): Promise<number> {
    try {
      const balance = await connection.getBalance(new PublicKey(address))
      return balance / LAMPORTS_PER_SOL
    } catch {
      return 0
    }
  }

  private async uploadMetadata(metadata: any): Promise<string> {
    const { uri } = await this.metaplex.nfts().uploadMetadata(metadata)
    return uri
  }
}

export const web3Service = new Web3Service()