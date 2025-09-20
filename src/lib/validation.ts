import { z } from 'zod'
import DOMPurify from 'dompurify'

// Track validation
export const trackSchema = z.object({
  title: z.string().min(1).max(100).regex(/^[a-zA-Z0-9\s\-_.,!?]+$/),
  description: z.string().max(1000).optional().transform(val => 
    val ? DOMPurify.sanitize(val) : undefined
  ),
  duration: z.number().positive().max(3600),
  fileHash: z.string().regex(/^[a-fA-F0-9]{64}$/),
  genre: z.enum(['electronic', 'hip-hop', 'rock', 'pop', 'classical', 'jazz', 'other'])
})

// Wallet validation
export const walletSchema = z.string()
  .regex(/^[1-9A-HJ-NP-Za-km-z]{32,44}$/, 'Invalid Solana address')

// NFT validation
export const nftSchema = z.object({
  name: z.string().min(1).max(50),
  description: z.string().max(500),
  image: z.string().url(),
  royalty: z.number().min(0).max(50),
  supply: z.number().positive().max(10000)
})

// Validation middleware
export function validate<T>(schema: z.ZodSchema<T>) {
  return (req: any, res: any, next: any) => {
    try {
      req.body = schema.parse(req.body)
      next()
    } catch (error) {
      res.status(400).json({ 
        error: 'Validation failed', 
        details: error instanceof z.ZodError ? error.errors : 'Invalid input'
      })
    }
  }
}