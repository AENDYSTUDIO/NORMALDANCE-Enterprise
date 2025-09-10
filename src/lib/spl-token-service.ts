import { Connection, PublicKey, Keypair } from '@solana/web3.js'
import { Metaplex, keypairIdentity, bundlrStorage } from '@metaplex-foundation/js'

export interface MusicNFTMetadata {
  name: string
  symbol: string
  description: string
  image: string
  animation_url?: string
  external_url?: string
  attributes: Array<{ trait_type: string; value: string | number }>
  properties: {
    files: Array<{ uri: string; type: string }>
    category: 'audio' | 'video' | 'image'
  }
}

export interface RoyaltyConfig {
  percentage: number
  recipients: Array<{ address: string; share: number }>
}

export class SPLTokenService {
  private metaplex: Metaplex
  private connection: Connection

  constructor(connection: Connection, keypair?: Keypair) {
    this.connection = connection
    this.metaplex = Metaplex.make(connection)
      .use(bundlrStorage({
        address: 'https://devnet.bundlr.network',
        providerUrl: 'https://api.devnet.solana.com',
        timeout: 60000,
      }))
    
    if (keypair) {
      this.metaplex.use(keypairIdentity(keypair))
    }
  }

  async mintMusicNFT(
    metadata: MusicNFTMetadata,
    royalty: RoyaltyConfig,
    collectionMint?: PublicKey
  ) {
    try {
      const metadataUri = await this.uploadMetadata(metadata)
      
      const { nft } = await this.metaplex.nfts().create({
        uri: metadataUri,
        name: metadata.name,
        symbol: metadata.symbol,
        sellerFeeBasisPoints: royalty.percentage * 100,
        creators: royalty.recipients.map(recipient => ({
          address: new PublicKey(recipient.address),
          share: recipient.share,
          verified: false
        })),
        collection: collectionMint ? { address: collectionMint, verified: false } : undefined,
        uses: {
          useMethod: 'Single',
          remaining: 1,
          total: 1
        }
      })

      return {
        success: true,
        mint: nft.address,
        metadata: nft.metadataAddress,
        uri: metadataUri
      }
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }
    }
  }

  async createCollection(name: string, symbol: string, description: string, image: string) {
    const metadata: MusicNFTMetadata = {
      name,
      symbol,
      description,
      image,
      attributes: [{ trait_type: 'Type', value: 'Collection' }],
      properties: {
        files: [{ uri: image, type: 'image/png' }],
        category: 'image'
      }
    }

    const { nft } = await this.metaplex.nfts().create({
      uri: await this.uploadMetadata(metadata),
      name,
      symbol,
      sellerFeeBasisPoints: 0,
      isCollection: true
    })

    return nft
  }

  private async uploadMetadata(metadata: MusicNFTMetadata): Promise<string> {
    const { uri } = await this.metaplex.nfts().uploadMetadata(metadata)
    return uri
  }

  async verifyCollection(nftMint: PublicKey, collectionMint: PublicKey) {
    await this.metaplex.nfts().verifyCollection({
      mintAddress: nftMint,
      collectionMintAddress: collectionMint
    })
  }
}