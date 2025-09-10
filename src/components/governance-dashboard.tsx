'use client'

import { useState, useEffect } from 'react'
import { useWallet } from '@solana/wallet-adapter-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'

interface Proposal {
  id: string
  title: string
  description: string
  status: 'active' | 'passed' | 'rejected'
  votesFor: number
  votesAgainst: number
  totalVotes: number
  endTime: Date
  proposer: string
}

interface TreasuryStats {
  totalValue: number
  ndtBalance: number
  solBalance: number
  monthlyBurn: number
}

export function GovernanceDashboard() {
  const { connected, publicKey } = useWallet()
  const [proposals, setProposals] = useState<Proposal[]>([])
  const [treasury, setTreasury] = useState<TreasuryStats | null>(null)
  const [userVotingPower, setUserVotingPower] = useState(0)

  useEffect(() => {
    if (connected) {
      loadProposals()
      loadTreasuryStats()
      loadUserVotingPower()
    }
  }, [connected])

  const loadProposals = async () => {
    setProposals([
      {
        id: '1',
        title: 'Increase Artist Royalty Rate',
        description: 'Proposal to increase base royalty rate from 5% to 7.5%',
        status: 'active',
        votesFor: 15000,
        votesAgainst: 8000,
        totalVotes: 23000,
        endTime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        proposer: 'Artist DAO'
      }
    ])
  }

  const loadTreasuryStats = async () => {
    setTreasury({
      totalValue: 2500000,
      ndtBalance: 1000000,
      solBalance: 15000,
      monthlyBurn: 50000
    })
  }

  const loadUserVotingPower = async () => {
    if (publicKey) {
      setUserVotingPower(1250)
    }
  }

  const handleVote = async (proposalId: string, support: boolean) => {
    try {
      console.log(`Voting ${support ? 'for' : 'against'} proposal ${proposalId}`)
    } catch (error) {
      console.error('Voting failed:', error)
    }
  }

  if (!connected) {
    return (
      <div className="text-center py-8">
        <p>Connect your wallet to access DAO governance</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Your Voting Power</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{userVotingPower.toLocaleString()}</div>
            <p className="text-sm text-gray-500">NDT Tokens Staked</p>
          </CardContent>
        </Card>

        {treasury && (
          <>
            <Card>
              <CardHeader>
                <CardTitle>Treasury Value</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">${treasury.totalValue.toLocaleString()}</div>
                <p className="text-sm text-gray-500">Total Assets</p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Monthly Burn</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{treasury.monthlyBurn.toLocaleString()}</div>
                <p className="text-sm text-gray-500">NDT Tokens</p>
              </CardContent>
            </Card>
          </>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Active Proposals</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {proposals.map((proposal) => (
              <div key={proposal.id} className="border rounded-lg p-4">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="font-semibold">{proposal.title}</h3>
                  <span className={`px-2 py-1 rounded text-xs ${
                    proposal.status === 'active' ? 'bg-green-100 text-green-800' :
                    proposal.status === 'passed' ? 'bg-blue-100 text-blue-800' :
                    'bg-red-100 text-red-800'
                  }`}>
                    {proposal.status.toUpperCase()}
                  </span>
                </div>
                
                <p className="text-sm text-gray-600 mb-3">{proposal.description}</p>
                
                <div className="space-y-2 mb-3">
                  <div className="flex justify-between text-sm">
                    <span>For: {proposal.votesFor.toLocaleString()}</span>
                    <span>Against: {proposal.votesAgainst.toLocaleString()}</span>
                  </div>
                  <Progress 
                    value={(proposal.votesFor / proposal.totalVotes) * 100} 
                    className="h-2"
                  />
                </div>

                {proposal.status === 'active' && (
                  <div className="flex gap-2">
                    <Button 
                      size="sm" 
                      onClick={() => handleVote(proposal.id, true)}
                      className="bg-green-600 hover:bg-green-700"
                    >
                      Vote For
                    </Button>
                    <Button 
                      size="sm" 
                      variant="outline"
                      onClick={() => handleVote(proposal.id, false)}
                    >
                      Vote Against
                    </Button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}