import { Connection, PublicKey, Transaction, SystemProgram, LAMPORTS_PER_SOL } from '@solana/web3.js'
import { Token, TOKEN_PROGRAM_ID } from '@solana/spl-token'

const SOLANA_RPC = process.env.NEXT_PUBLIC_SOLANA_RPC || 'https://api.devnet.solana.com'
const connection = new Connection(SOLANA_RPC, 'confirmed')

export async function getWalletBalance(address: string): Promise<number> {
  try {
    const publicKey = new PublicKey(address)
    const balance = await connection.getBalance(publicKey)
    return balance / LAMPORTS_PER_SOL
  } catch {
    return 0
  }
}

export async function mintNFT(
  walletAddress: string,
  metadata: { name: string; symbol: string; uri: string }
): Promise<string> {
  // Минимальная реализация минтинга NFT
  const transaction = new Transaction()
  
  // TODO: Добавить реальную логику минтинга через Metaplex
  const instruction = SystemProgram.transfer({
    fromPubkey: new PublicKey(walletAddress),
    toPubkey: new PublicKey(walletAddress),
    lamports: 0,
  })
  
  transaction.add(instruction)
  return transaction.serialize().toString('base64')
}

export async function createStakePool(
  authority: string,
  tokenMint: string,
  rewardRate: number
): Promise<string> {
  // Минимальная реализация создания стейк пула
  const transaction = new Transaction()
  
  // TODO: Добавить реальную логику создания стейк пула
  const instruction = SystemProgram.createAccount({
    fromPubkey: new PublicKey(authority),
    newAccountPubkey: new PublicKey(authority),
    lamports: 0,
    space: 0,
    programId: TOKEN_PROGRAM_ID,
  })
  
  transaction.add(instruction)
  return transaction.serialize().toString('base64')
}