import { DeflationaryModel, DEFALATIONARY_CONFIG, deflationUtils } from '../deflationary-model'
import { Connection, PublicKey } from '@solana/web3.js'

// Mock connection
const mockConnection = {} as Connection

describe('Deflationary Model', () => {
  let model: DeflationaryModel

  beforeEach(() => {
    // @ts-ignore - Mock connection for testing
    model = new DeflationaryModel(mockConnection)
  })

  describe('DeflationaryModel', () => {
    describe('calculateBurnAmount', () => {
      it('should calculate burn amount correctly', () => {
        const amount = 1000
        const burnAmount = model.calculateBurnAmount(amount)
        
        expect(burnAmount).toBe(20) // 2% of 1000
      })

      it('should handle zero amount', () => {
        const amount = 0
        const burnAmount = model.calculateBurnAmount(amount)
        
        expect(burnAmount).toBe(0)
      })

      it('should handle large amounts', () => {
        const amount = 1000000
        const burnAmount = model.calculateBurnAmount(amount)
        
        expect(burnAmount).toBe(20000) // 2% of 1,000,000
      })

      it('should handle fractional amounts', () => {
        const amount = 500
        const burnAmount = model.calculateBurnAmount(amount)
        
        expect(burnAmount).toBe(10) // 2% of 500
      })
    })

    describe('calculateStakingRewards', () => {
      it('should calculate staking rewards correctly', () => {
        const burnAmount = 100
        const rewards = model.calculateStakingRewards(burnAmount)
        
        expect(rewards).toBe(20) // 20% of burn amount
      })

      it('should handle zero burn amount', () => {
        const burnAmount = 0
        const rewards = model.calculateStakingRewards(burnAmount)
        
        expect(rewards).toBe(0)
      })
    })

    describe('calculateTreasuryAmount', () => {
      it('should calculate treasury amount correctly', () => {
        const burnAmount = 100
        const treasuryAmount = model.calculateTreasuryAmount(burnAmount)
        
        expect(treasuryAmount).toBe(30) // 30% of burn amount
      })

      it('should handle zero burn amount', () => {
        const burnAmount = 0
        const treasuryAmount = model.calculateTreasuryAmount(burnAmount)
        
        expect(treasuryAmount).toBe(0)
      })
    })

    describe('formatTokenAmount', () => {
      it('should format token amount correctly', () => {
        const amount = 1234.567890
        const formatted = model.formatTokenAmount(amount)
        
        expect(formatted).toBe('1,234.567890')
      })

      it('should handle small amounts', () => {
        const amount = 0.001
        const formatted = model.formatTokenAmount(amount)
        
        expect(formatted).toBe('0.00')
      })
    })

    describe('getDeflationInfo', () => {
      it('should return deflation information', () => {
        const info = model.getDeflationInfo()
        
        expect(info.config).toBeDefined()
        expect(info.description).toBeDefined()
        expect(info.benefits).toBeDefined()
        expect(info.benefits.length).toBeGreaterThan(0)
      })
    })
  })

  describe('deflationUtils', () => {
    describe('calculateEffectivePrice', () => {
      it('should calculate effective price correctly', () => {
        const basePrice = 100
        const burnPercentage = 2
        const effectivePrice = deflationUtils.calculateEffectivePrice(basePrice, burnPercentage)
        
        expect(effectivePrice).toBe(102) // 100 + 2%
      })

      it('should handle zero burn percentage', () => {
        const basePrice = 100
        const burnPercentage = 0
        const effectivePrice = deflationUtils.calculateEffectivePrice(basePrice, burnPercentage)
        
        expect(effectivePrice).toBe(100)
      })
    })

    describe('calculateStakingROI', () => {
      it('should calculate staking ROI correctly', () => {
        const stakeAmount = 1000
        const apy = 10
        const days = 365
        const burnRate = 2
        const roi = deflationUtils.calculateStakingROI(stakeAmount, apy, days, burnRate)
        
        expect(roi).toBeGreaterThan(0)
        expect(roi).toBeGreaterThan(stakeAmount * 0.1) // Should be more than base APY
      })

      it('should handle zero stake amount', () => {
        const stakeAmount = 0
        const apy = 10
        const days = 365
        const burnRate = 2
        const roi = deflationUtils.calculateStakingROI(stakeAmount, apy, days, burnRate)
        
        expect(roi).toBe(0)
      })
    })

    describe('formatDeflationProgress', () => {
      it('should format deflation progress correctly', () => {
        const totalBurned = 50000000
        const totalSupply = 1000000000
        const progress = deflationUtils.formatDeflationProgress(totalBurned, totalSupply)
        
        expect(progress).toBe('5.00% сожжено')
      })

      it('should handle zero burned tokens', () => {
        const totalBurned = 0
        const totalSupply = 1000000000
        const progress = deflationUtils.formatDeflationProgress(totalBurned, totalSupply)
        
        expect(progress).toBe('0.00% сожжено')
      })
    })

    describe('getDeflationColor', () => {
      it('should return green color for low deflation', () => {
        const color = deflationUtils.getDeflationColor(3)
        
        expect(color).toBe('text-green-600')
      })

      it('should return yellow color for medium deflation', () => {
        const color = deflationUtils.getDeflationColor(10)
        
        expect(color).toBe('text-yellow-600')
      })

      it('should return red color for high deflation', () => {
        const color = deflationUtils.getDeflationColor(20)
        
        expect(color).toBe('text-red-600')
      })
    })
  })

  describe('DEFALATIONARY_CONFIG', () => {
    it('should have correct configuration', () => {
      expect(DEFALATIONARY_CONFIG.totalSupply).toBe(1000000000)
      expect(DEFALATIONARY_CONFIG.burnPercentage).toBe(2)
      expect(DEFALATIONARY_CONFIG.stakingRewardsPercentage).toBe(20)
      expect(DEFALATIONARY_CONFIG.treasuryPercentage).toBe(30)
      expect(DEFALATIONARY_CONFIG.maxSupply).toBe(2000000000)
      expect(DEFALATIONARY_CONFIG.decimals).toBe(9)
    })
  })
})