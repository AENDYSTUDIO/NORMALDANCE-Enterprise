'use client'

import { useState, useCallback } from 'react'
import { useWallet } from '@solana/wallet-adapter-react'
import { useDropzone } from 'react-dropzone'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Progress } from '@/components/ui/progress'
import { Badge } from '@/components/ui/badge'
import { SPLTokenService } from '@/lib/spl-token-service'
import { IPFSEnhancedService } from '@/lib/ipfs-enhanced-service'

interface MintingStep {
  id: string
  title: string
  status: 'pending' | 'active' | 'completed' | 'error'
  progress: number
}

export function EnhancedNFTMinting() {
  const { connected, publicKey, connection } = useWallet()
  const [currentStep, setCurrentStep] = useState(0)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [mintingSteps, setMintingSteps] = useState<MintingStep[]>([
    { id: 'upload', title: 'Upload Files', status: 'active', progress: 0 },
    { id: 'metadata', title: 'Set Metadata', status: 'pending', progress: 0 },
    { id: 'royalties', title: 'Configure Royalties', status: 'pending', progress: 0 },
    { id: 'preview', title: 'Preview & Confirm', status: 'pending', progress: 0 },
    { id: 'mint', title: 'Mint NFT', status: 'pending', progress: 0 }
  ])

  const [formData, setFormData] = useState({
    name: '',
    description: '',
    audioFile: null as File | null,
    imageFile: null as File | null,
    attributes: [{ trait_type: '', value: '' }],
    royaltyPercentage: 5,
    royaltyRecipients: [{ address: '', share: 100 }],
    collection: '',
    price: 0
  })

  const onDrop = useCallback((acceptedFiles: File[]) => {
    acceptedFiles.forEach(file => {
      if (file.type.startsWith('audio/')) {
        setFormData(prev => ({ ...prev, audioFile: file }))
      } else if (file.type.startsWith('image/')) {
        setFormData(prev => ({ ...prev, imageFile: file }))
      }
    })
  }, [])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'audio/*': ['.mp3', '.wav', '.flac'],
      'image/*': ['.png', '.jpg', '.jpeg', '.gif']
    },
    multiple: true
  })

  const updateStep = (stepId: string, status: MintingStep['status'], progress: number = 0) => {
    setMintingSteps(prev => prev.map(step => 
      step.id === stepId ? { ...step, status, progress } : step
    ))
  }

  const handleMint = async () => {
    if (!connected || !publicKey || !connection) return

    try {
      updateStep('upload', 'active', 0)

      // Initialize services
      const ipfsService = new IPFSEnhancedService(process.env.NEXT_PUBLIC_WEB3_STORAGE_TOKEN!)
      const splService = new SPLTokenService(connection)

      // Upload files to IPFS
      let imageCid = ''
      let audioCid = ''

      if (formData.imageFile) {
        updateStep('upload', 'active', 25)
        imageCid = await ipfsService.uploadWithChunking(
          formData.imageFile,
          (progress) => setUploadProgress(progress.percentage)
        )
      }

      if (formData.audioFile) {
        updateStep('upload', 'active', 75)
        audioCid = await ipfsService.uploadWithChunking(
          formData.audioFile,
          (progress) => setUploadProgress(50 + progress.percentage / 2)
        )
      }

      updateStep('upload', 'completed', 100)
      updateStep('metadata', 'active', 0)

      // Prepare metadata
      const metadata = {
        name: formData.name,
        symbol: 'NDT',
        description: formData.description,
        image: imageCid ? `https://ipfs.io/ipfs/${imageCid}` : '',
        animation_url: audioCid ? `https://ipfs.io/ipfs/${audioCid}` : undefined,
        external_url: `https://normaldance.com/nft/${Date.now()}`,
        attributes: formData.attributes.filter(attr => attr.trait_type && attr.value),
        properties: {
          files: [
            ...(imageCid ? [{ uri: `https://ipfs.io/ipfs/${imageCid}`, type: 'image/png' }] : []),
            ...(audioCid ? [{ uri: `https://ipfs.io/ipfs/${audioCid}`, type: 'audio/mpeg' }] : [])
          ],
          category: 'audio' as const
        }
      }

      updateStep('metadata', 'completed', 100)
      updateStep('royalties', 'active', 0)

      // Configure royalties
      const royaltyConfig = {
        percentage: formData.royaltyPercentage / 100,
        recipients: formData.royaltyRecipients.filter(r => r.address)
      }

      updateStep('royalties', 'completed', 100)
      updateStep('preview', 'active', 0)

      // Show preview (simulate delay)
      await new Promise(resolve => setTimeout(resolve, 1000))
      updateStep('preview', 'completed', 100)
      updateStep('mint', 'active', 0)

      // Mint NFT
      const result = await splService.mintMusicNFT(metadata, royaltyConfig)

      if (result.success) {
        updateStep('mint', 'completed', 100)
        console.log('NFT minted successfully:', result.mint)
      } else {
        updateStep('mint', 'error', 0)
        console.error('Minting failed:', result.error)
      }

    } catch (error) {
      console.error('Minting process failed:', error)
      updateStep('mint', 'error', 0)
    }
  }

  const addAttribute = () => {
    setFormData(prev => ({
      ...prev,
      attributes: [...prev.attributes, { trait_type: '', value: '' }]
    }))
  }

  const updateAttribute = (index: number, field: 'trait_type' | 'value', value: string) => {
    setFormData(prev => ({
      ...prev,
      attributes: prev.attributes.map((attr, i) => 
        i === index ? { ...attr, [field]: value } : attr
      )
    }))
  }

  if (!connected) {
    return (
      <div className="text-center py-8">
        <p>Connect your wallet to start minting NFTs</p>
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Progress Steps */}
      <Card>
        <CardHeader>
          <CardTitle>Minting Progress</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex justify-between mb-4">
            {mintingSteps.map((step, index) => (
              <div key={step.id} className="flex flex-col items-center">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                  step.status === 'completed' ? 'bg-green-500 text-white' :
                  step.status === 'active' ? 'bg-blue-500 text-white' :
                  step.status === 'error' ? 'bg-red-500 text-white' :
                  'bg-gray-200 text-gray-600'
                }`}>
                  {index + 1}
                </div>
                <span className="text-xs mt-1 text-center">{step.title}</span>
                {step.status === 'active' && step.progress > 0 && (
                  <Progress value={step.progress} className="w-16 h-1 mt-1" />
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* File Upload */}
      <Card>
        <CardHeader>
          <CardTitle>Upload Files</CardTitle>
        </CardHeader>
        <CardContent>
          <div
            {...getRootProps()}
            className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors ${
              isDragActive ? 'border-blue-500 bg-blue-50' : 'border-gray-300'
            }`}
          >
            <input {...getInputProps()} />
            <p className="text-lg mb-2">
              {isDragActive ? 'Drop files here...' : 'Drag & drop files here, or click to select'}
            </p>
            <p className="text-sm text-gray-500">
              Supported: MP3, WAV, FLAC (audio) and PNG, JPG, GIF (images)
            </p>
          </div>

          {(formData.audioFile || formData.imageFile) && (
            <div className="mt-4 space-y-2">
              {formData.audioFile && (
                <div className="flex items-center gap-2">
                  <Badge>Audio</Badge>
                  <span className="text-sm">{formData.audioFile.name}</span>
                </div>
              )}
              {formData.imageFile && (
                <div className="flex items-center gap-2">
                  <Badge>Image</Badge>
                  <span className="text-sm">{formData.imageFile.name}</span>
                </div>
              )}
            </div>
          )}

          {uploadProgress > 0 && uploadProgress < 100 && (
            <div className="mt-4">
              <Progress value={uploadProgress} className="w-full" />
              <p className="text-sm text-center mt-1">{uploadProgress.toFixed(1)}% uploaded</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Metadata Form */}
      <Card>
        <CardHeader>
          <CardTitle>NFT Metadata</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Name</label>
              <Input
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                placeholder="Enter NFT name"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Price (SOL)</label>
              <Input
                type="number"
                value={formData.price}
                onChange={(e) => setFormData(prev => ({ ...prev, price: parseFloat(e.target.value) }))}
                placeholder="0.1"
                min="0"
                step="0.01"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Description</label>
            <Textarea
              value={formData.description}
              onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
              placeholder="Describe your NFT"
              rows={3}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2">Attributes</label>
            {formData.attributes.map((attr, index) => (
              <div key={index} className="flex gap-2 mb-2">
                <Input
                  placeholder="Trait type"
                  value={attr.trait_type}
                  onChange={(e) => updateAttribute(index, 'trait_type', e.target.value)}
                />
                <Input
                  placeholder="Value"
                  value={attr.value}
                  onChange={(e) => updateAttribute(index, 'value', e.target.value)}
                />
              </div>
            ))}
            <Button type="button" variant="outline" onClick={addAttribute}>
              Add Attribute
            </Button>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Royalty Percentage</label>
            <Input
              type="number"
              value={formData.royaltyPercentage}
              onChange={(e) => setFormData(prev => ({ ...prev, royaltyPercentage: parseFloat(e.target.value) }))}
              placeholder="5"
              min="0"
              max="10"
              step="0.1"
            />
          </div>
        </CardContent>
      </Card>

      <div className="flex justify-end">
        <Button 
          onClick={handleMint}
          disabled={!formData.name || !formData.description || (!formData.audioFile && !formData.imageFile)}
          className="px-8"
        >
          Mint NFT
        </Button>
      </div>
    </div>
  )
}