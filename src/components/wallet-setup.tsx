'use client'

import { useState } from 'react'
import { useWallet, useConnection } from '@solana/wallet-adapter-react'
import { LAMPORTS_PER_SOL } from '@solana/web3.js'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'

export function WalletSetup() {
  const { connected, publicKey, disconnect } = useWallet()
  const { connection } = useConnection()
  const [balance, setBalance] = useState<number | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  const checkBalance = async () => {
    if (!publicKey) return
    
    setIsLoading(true)
    try {
      const bal = await connection.getBalance(publicKey)
      setBalance(bal / LAMPORTS_PER_SOL)
    } catch (error) {
      console.error('Error checking balance:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const requestAirdrop = async () => {
    if (!publicKey) return
    
    setIsLoading(true)
    try {
      const signature = await connection.requestAirdrop(publicKey, 2 * LAMPORTS_PER_SOL)
      await connection.confirmTransaction(signature)
      await checkBalance()
    } catch (error) {
      console.error('Airdrop failed:', error)
    } finally {
      setIsLoading(false)
    }
  }

  if (!connected) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Wallet Setup Required</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="mb-4">Connect your Phantom wallet to continue</p>
          <div className="space-y-2 text-sm text-gray-600">
            <p>1. Install Phantom extension</p>
            <p>2. Switch to Devnet in settings</p>
            <p>3. Click Connect Wallet</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          Wallet Connected 
          <Badge variant="outline">Devnet</Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <p className="text-sm text-gray-600">Address:</p>
          <p className="font-mono text-xs break-all">{publicKey?.toBase58()}</p>
        </div>
        
        <div className="flex items-center gap-2">
          <Button onClick={checkBalance} disabled={isLoading} size="sm">
            Check Balance
          </Button>
          {balance !== null && (
            <span className="text-sm">{balance.toFixed(4)} SOL</span>
          )}
        </div>

        {balance !== null && balance < 0.1 && (
          <div className="p-3 bg-yellow-50 border border-yellow-200 rounded">
            <p className="text-sm text-yellow-800 mb-2">Low balance detected</p>
            <Button onClick={requestAirdrop} disabled={isLoading} size="sm">
              Request 2 SOL (Devnet)
            </Button>
          </div>
        )}

        <Button onClick={disconnect} variant="outline" size="sm">
          Disconnect
        </Button>
      </CardContent>
    </Card>
  )
}