import { NextRequest, NextResponse } from 'next/server'
import { web3Service } from '@/lib/web3-real'
import { validateAmount, validateWalletAddress } from '@/lib/security'

export async function POST(request: NextRequest) {
  try {
    const { walletAddress, amount, lockPeriod } = await request.json()

    if (!validateWalletAddress(walletAddress) || !validateAmount(amount)) {
      return NextResponse.json({ error: 'Invalid input' }, { status: 400 })
    }

    const poolAddress = await web3Service.createStakingPool(walletAddress, 12, lockPeriod)

    return NextResponse.json({
      success: true,
      data: { poolAddress, amount, lockPeriod }
    })
  } catch (error) {
    return NextResponse.json({ error: 'Staking failed' }, { status: 500 })
  }
}