import { Connection, PublicKey } from '@solana/web3.js';
import { EnhancedNFTService } from '@/lib/web3/enhanced-nft';

describe('Web3 Integration Tests', () => {
  let nftService: EnhancedNFTService;
  
  beforeEach(() => {
    nftService = new EnhancedNFTService('https://api.devnet.solana.com');
  });

  test('should mint NFT with sanitized metadata', async () => {
    const maliciousMetadata = {
      name: '<script>alert("xss")</script>Track Name',
      description: 'javascript:alert("xss")',
      image: 'https://example.com/image.jpg',
      attributes: [
        { trait_type: 'Genre<script>', value: 'Electronic' }
      ]
    };

    const result = await nftService.mintMusicNFT(
      'test-wallet-address',
      'track-id',
      maliciousMetadata
    );

    expect(result).toBeDefined();
    expect(result).not.toContain('<script>');
    expect(result).not.toContain('javascript:');
  });

  test('should validate wallet addresses', async () => {
    const invalidWallet = '../../../etc/passwd';
    
    await expect(
      nftService.mintMusicNFT(invalidWallet, 'track-id', {
        name: 'Test',
        description: 'Test',
        image: 'test.jpg',
        attributes: []
      })
    ).rejects.toThrow();
  });
});