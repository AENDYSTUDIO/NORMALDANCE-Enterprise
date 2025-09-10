import { IPFSService, IPFSTrackMetadata } from '../ipfs-enhanced'

// Mock IPFS client
jest.mock('ipfs-http-client')
jest.mock('pinata-sdk')
jest.mock('file-type')
jest.mock('mime-types')

const mockIPFSClient = {
  add: jest.fn(),
  cat: jest.fn(),
  object: {
    stat: jest.fn(),
  },
  pin: {
    rm: jest.fn(),
  },
}

const mockPinata = {
  pinFile: jest.fn(),
  pinList: jest.fn(),
}

const mockFileType = {
  fileTypeFromBuffer: jest.fn(),
}

const mockMimeTypes = {
  lookup: jest.fn(),
}

beforeEach(() => {
  jest.clearAllMocks()
  // @ts-ignore - Jest mock setup
  const { create } = require('ipfs-http-client')
  create.mockReturnValue(mockIPFSClient)
  // @ts-ignore - Jest mock setup
  const PinataSDK = require('pinata-sdk').default || require('pinata-sdk')
  PinataSDK.mockReturnValue(mockPinata)
  // @ts-ignore - Jest mock setup
  const { fileTypeFromBuffer } = require('file-type')
  fileTypeFromBuffer.mockResolvedValue({ mime: 'audio/mpeg', ext: 'mp3' })
  // @ts-ignore - Jest mock setup
  const { lookup } = require('mime-types')
  lookup.mockReturnValue('audio/mpeg')
})

describe('IPFS Integration', () => {
  let ipfsService: IPFSService
  
  beforeEach(() => {
    ipfsService = new IPFSService()
  })

  const mockMetadata: IPFSTrackMetadata = {
    title: 'Test Track',
    artist: 'Test Artist',
    genre: 'Electronic',
    duration: 180,
    releaseDate: '2024-01-01',
  }

  const mockFile = new File(['test audio content'], 'test.mp3', {
    type: 'audio/mpeg',
  })

  describe('uploadWithReplication', () => {
    it('should upload file to IPFS successfully', async () => {
      const mockResult = {
        cid: 'test-cid-123',
        size: 1024000,
      }
      
      mockIPFSClient.add.mockResolvedValue(mockResult)

      const result = await ipfsService.uploadWithReplication(mockFile, {
        filename: 'test.mp3',
        contentType: 'audio/mpeg',
        metadata: mockMetadata
      })

      expect(result).toEqual({
        cid: 'test-cid-123',
        url: 'https://ipfs.io/ipfs/test-cid-123',
        size: 1024000,
        mimeType: 'audio/mpeg',
        timestamp: expect.any(Number),
        gatewayUrls: [
          'https://ipfs.io/ipfs/test-cid-123',
          'https://cloudflare-ipfs.com/ipfs/test-cid-123',
          'https://gateway.pinata.cloud/ipfs/test-cid-123',
          'https://ipfs.infura.io/ipfs/test-cid-123'
        ],
        replicationStatus: {
          ipfs: true,
          filecoin: false,
          cdn: false
        }
      })

      expect(mockIPFSClient.add).toHaveBeenCalledWith(
        expect.objectContaining({
          content: expect.any(Uint8Array),
          path: 'test.mp3',
          pin: true,
          metadata: mockMetadata
        })
      )
    })

    it('should handle IPFS upload failure', async () => {
      mockIPFSClient.add.mockRejectedValue(new Error('Upload failed'))

      await expect(
        ipfsService.uploadWithReplication(mockFile, {
          filename: 'test.mp3',
          contentType: 'audio/mpeg'
        })
      ).rejects.toThrow('IPFS upload failed: Upload failed')
    })
  })

  describe('getFileInfo', () => {
    it('should retrieve file info successfully', async () => {
      const mockStats = {
        CumulativeSize: 1024000,
        Type: 'pinned',
        Ts: 1234567890
      }
      
      mockIPFSClient.object.stat.mockResolvedValue(mockStats)

      const result = await ipfsService.getFileInfo('test-cid')

      expect(result).toEqual({
        cid: 'test-cid',
        size: 1024000,
        type: 'pinned',
        pinned: true,
        timestamp: 1234567890
      })

      expect(mockIPFSClient.object.stat).toHaveBeenCalledWith('test-cid')
    })

    it('should handle file info retrieval failure', async () => {
      mockIPFSClient.object.stat.mockRejectedValue(new Error('File not found'))

      await expect(ipfsService.getFileInfo('test-cid')).rejects.toThrow(
        'Failed to get file info: File not found'
      )
    })
  })

  describe('checkFileAvailabilityOnMultipleGateways', () => {
    it('should check file availability on multiple gateways', async () => {
      const mockResponse = {
        ok: true,
        status: 200
      }
      
      global.fetch = jest.fn().mockResolvedValue(mockResponse)

      const result = await ipfsService.checkFileAvailabilityOnMultipleGateways('test-cid')

      expect(result).toHaveProperty('available')
      expect(result).toHaveProperty('unavailable')
      expect(result).toHaveProperty('fastest')
      expect(Array.isArray(result.available)).toBe(true)
      expect(Array.isArray(result.unavailable)).toBe(true)
    })
  })

  describe('searchByCID', () => {
    it('should search for file by CID', async () => {
      const mockResponse = {
        ok: true,
        status: 200
      }
      
      global.fetch = jest.fn().mockResolvedValue(mockResponse)

      const result = await ipfsService.searchByCID('test-cid')

      expect(result).toEqual({
        exists: true,
        gateways: expect.arrayContaining([
          expect.stringContaining('https://')
        ])
      })
    })
  })

  describe('unpinFile', () => {
    it('should unpin file successfully', async () => {
      mockIPFSClient.pin.rm.mockResolvedValue(undefined)

      const result = await ipfsService.unpinFile('test-cid')

      expect(result).toBe(true)
      expect(mockIPFSClient.pin.rm).toHaveBeenCalledWith('test-cid')
    })

    it('should handle unpin failure', async () => {
      mockIPFSClient.pin.rm.mockRejectedValue(new Error('Unpin failed'))

      const result = await ipfsService.unpinFile('test-cid')

      expect(result).toBe(false)
    })
  })
})