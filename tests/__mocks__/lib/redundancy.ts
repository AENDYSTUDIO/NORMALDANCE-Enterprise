// Mock file for lib/redundancy module
const uploadToRedundancyStorage = jest.fn()
const calculatePrice = jest.fn()
const validateProviders = jest.fn()
const calculateReplicationScore = jest.fn()

export const REDUNDANCY_CONFIG = {
  providers: ['arweave', 'sia', 'storj'],
  defaultReplicationFactor: 3,
  maxReplicationFactor: 10,
  minReplicationFactor: 1,
  defaultDuration: 365,
  pricing: {
    arweave: 0.1,
    sia: 0.05,
    storj: 0.03,
  }
}

export const redundancyUtils = {
  calculatePrice,
  validateProviders,
  calculateReplicationScore,
}

export default {
  uploadToRedundancyStorage,
  REDUNDANCY_CONFIG,
  redundancyUtils,
}

export { uploadToRedundancyStorage }