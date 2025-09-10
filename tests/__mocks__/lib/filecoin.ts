// Mock file for lib/filecoin module
const uploadToFilecoin = jest.fn()
const calculateFilecoinPrice = jest.fn()
const validateFilecoinDeal = jest.fn()

export const FILECOIN_CONFIG = {
  defaultDuration: 365,
  minDuration: 30,
  maxDuration: 1095,
  replicationFactor: 3,
  pricing: {
    basePrice: 0.001,
    sizeMultiplier: 0.00001,
    durationMultiplier: 0.0001,
  },
  providers: ['filecoin', 'arweave', 'sia'],
}

export const filecoinUtils = {
  calculatePrice: calculateFilecoinPrice,
  validateDeal: validateFilecoinDeal,
  estimateDealCost: jest.fn(),
}

export default {
  uploadToFilecoin,
  FILECOIN_CONFIG,
  filecoinUtils,
}

export { uploadToFilecoin }