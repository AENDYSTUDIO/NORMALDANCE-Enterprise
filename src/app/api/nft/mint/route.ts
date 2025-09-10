import { NextRequest, NextResponse } from 'next/server'
import { Connection, PublicKey } from '@solana/web3.js'
import { SPLTokenService } from '@/lib/spl-token-service'
import { IPFSEnhancedService } from '@/lib/ipfs-enhanced-service'
import rateLimit from '@/lib/rate-limit'

const limiter = rateLimit({
  interval: 60 * 1000, // 1 minute
  uniqueTokenPerInterval: 500,
})

export async function POST(request: NextRequest) {
  try {
    // Rate limiting
    await limiter.check(request, 10, 'CACHE_TOKEN')

    const body = await request.json()
    const {
      name,
      description,
      imageUrl,
      audioUrl,
      attributes,
      royaltyPercentage,
      royaltyRecipients,
      walletAddress,
      collectionId
    } = body

    // Validate required fields
    if (!name || !description || !walletAddress) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      )
    }

    // Initialize Solana connection
    const connection = new Connection(
      process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com'
    )

    const splService = new SPLTokenService(connection)

    // Prepare metadata
    const metadata = {
      name,
      symbol: 'NDT',
      description,
      image: imageUrl,
      animation_url: audioUrl,
      external_url: `https://normaldance.com/nft/${Date.now()}`,
      attributes: attributes || [],
      properties: {
        files: [
          ...(imageUrl ? [{ uri: imageUrl, type: 'image/png' }] : []),
          ...(audioUrl ? [{ uri: audioUrl, type: 'audio/mpeg' }] : [])
        ],
        category: 'audio' as const
      }
    }

    // Configure royalties
    const royaltyConfig = {
      percentage: (royaltyPercentage || 5) / 100,
      recipients: royaltyRecipients || [{ address: walletAddress, share: 100 }]
    }

    // Mint NFT
    const result = await splService.mintMusicNFT(
      metadata,
      royaltyConfig,
      collectionId ? new PublicKey(collectionId) : undefined
    )

    if (result.success) {
      return NextResponse.json({
        success: true,
        mint: result.mint?.toBase58(),
        metadata: result.metadata?.toBase58(),
        uri: result.uri
      })
    } else {
      return NextResponse.json(
        { error: result.error },
        { status: 500 }
      )
    }

  } catch (error) {
    console.error('Mint API error:', error)
    
    if (error instanceof Error && error.message === 'Rate limit exceeded') {
      return NextResponse.json(
        { error: 'Rate limit exceeded' },
        { status: 429 }
      )
    }

    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const mint = searchParams.get('mint')

    if (!mint) {
      return NextResponse.json(
        { error: 'Mint address required' },
        { status: 400 }
      )
    }

    const connection = new Connection(
      process.env.SOLANA_RPC_URL || 'https://api.devnet.solana.com'
    )

    const splService = new SPLTokenService(connection)
    
    // Get NFT metadata
    const nft = await splService.metaplex.nfts().findByMint({
      mintAddress: new PublicKey(mint)
    })

    return NextResponse.json({
      success: true,
      nft: {
        mint: nft.address.toBase58(),
        name: nft.name,
        symbol: nft.symbol,
        description: nft.json?.description,
        image: nft.json?.image,
        attributes: nft.json?.attributes,
        creators: nft.creators.map(creator => ({
          address: creator.address.toBase58(),
          share: creator.share,
          verified: creator.verified
        }))
      }
    })

  } catch (error) {
    console.error('Get NFT API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch NFT' },
      { status: 500 }
    )
  }
}