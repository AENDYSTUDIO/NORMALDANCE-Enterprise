import { NextRequest, NextResponse } from 'next/server'
import { PublicKey } from '@solana/web3.js'

const BLACKLISTED_WALLETS = new Set([
  // Add known malicious wallet addresses
])

const MAX_TRANSACTION_VALUE = 1000 // SOL

export async function validateWallet(walletAddress: string): Promise<{
  isValid: boolean
  risks: string[]
}> {
  const risks: string[] = []
  
  try {
    new PublicKey(walletAddress)
  } catch {
    return { isValid: false, risks: ['Invalid wallet address'] }
  }
  
  if (BLACKLISTED_WALLETS.has(walletAddress)) {
    risks.push('Blacklisted wallet')
  }
  
  return { isValid: risks.length === 0, risks }
}

export async function validateTransaction(transaction: any): Promise<{
  isValid: boolean
  risks: string[]
}> {
  const risks: string[] = []
  
  // Check transaction value
  if (transaction.value > MAX_TRANSACTION_VALUE) {
    risks.push('High value transaction')
  }
  
  // Check for suspicious patterns
  if (transaction.instructions?.length > 10) {
    risks.push('Complex transaction')
  }
  
  return { isValid: risks.length === 0, risks }
}

export function web3SecurityMiddleware() {
  return async (req: NextRequest) => {
    const { walletAddress, transaction } = await req.json()
    
    if (walletAddress) {
      const walletValidation = await validateWallet(walletAddress)
      if (!walletValidation.isValid) {
        return NextResponse.json({ 
          error: 'Wallet validation failed', 
          risks: walletValidation.risks 
        }, { status: 403 })
      }
    }
    
    if (transaction) {
      const txValidation = await validateTransaction(transaction)
      if (!txValidation.isValid) {
        return NextResponse.json({ 
          error: 'Transaction validation failed', 
          risks: txValidation.risks 
        }, { status: 403 })
      }
    }
    
    return NextResponse.next()
  }
}