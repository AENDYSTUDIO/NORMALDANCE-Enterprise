import { NextRequest, NextResponse } from 'next/server'
import { web3Limit } from '@/middleware/rate-limiter'
import { validateWallet, validateTransaction } from '@/middleware/web3-security'

export async function POST(req: NextRequest) {
  try {
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
    
    return NextResponse.json({ valid: true })
  } catch (error) {
    return NextResponse.json({ error: 'Validation failed' }, { status: 400 })
  }
}