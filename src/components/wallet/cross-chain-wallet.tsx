'use client';

import { useState } from 'react';
import { CrossChainManager, SupportedChains } from '@/lib/blockchain/cross-chain';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

const crossChainManager = new CrossChainManager();

export function CrossChainWallet() {
  const [selectedChain, setSelectedChain] = useState<SupportedChains>(SupportedChains.SOLANA);
  const [balance, setBalance] = useState<number>(0);

  const handleChainSwitch = async (chain: SupportedChains) => {
    setSelectedChain(chain);
    const newBalance = await crossChainManager.getChainBalance(chain, 'mock-address');
    setBalance(newBalance);
  };

  const handleBridge = async () => {
    const targetChain = selectedChain === SupportedChains.SOLANA ? SupportedChains.ETHEREUM : SupportedChains.SOLANA;
    await crossChainManager.bridgeAsset(selectedChain, targetChain, 10);
  };

  return (
    <div className="p-4 border rounded-lg">
      <h3 className="text-lg font-semibold mb-4">Cross-Chain Wallet</h3>
      
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-2">Select Chain</label>
          <Select value={selectedChain} onValueChange={handleChainSwitch}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {crossChainManager.getSupportedChains().map((chain) => (
                <SelectItem key={chain} value={chain}>
                  {chain.toUpperCase()}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div>
          <p className="text-sm text-gray-600">Balance: {balance.toFixed(4)}</p>
        </div>

        <Button onClick={handleBridge} className="w-full">
          Bridge Assets
        </Button>
      </div>
    </div>
  );
}