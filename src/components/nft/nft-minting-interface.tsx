import React, { useState, useEffect } from 'react'
import { useWallet } from '@solana/wallet-adapter-react'
import { Connection, PublicKey, Transaction, SystemProgram, LAMPORTS_PER_SOL } from '@solana/web3.js'
import { NFTMintingService, NFTMetadata, NFTCollection, NFTType, MintRequest } from '@/lib/nft-minting-service'
import { ipfsService } from '@/lib/ipfs-enhanced'
import { toast } from 'react-toastify'

interface NFTMintingInterfaceProps {
  trackId?: string
  artistId?: string
  onClose?: () => void
}

const NFTMintingInterface: React.FC<NFTMintingInterfaceProps> = ({ 
  trackId, 
  artistId, 
  onClose 
}) => {
  const { publicKey, sendTransaction, connected } = useWallet()
  const [nftService] = useState(() => new NFTMintingService())
  
  // Состояния для формы минтинга
  const [collections, setCollections] = useState<NFTCollection[]>([])
  const [selectedCollection, setSelectedCollection] = useState<string>('')
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [price, setPrice] = useState(0)
  const [quantity, setQuantity] = useState(1)
  const [royaltyPercentage, setRoyaltyPercentage] = useState(10)
  const [royaltyAddress, setRoyaltyAddress] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [animationUrl, setAnimationUrl] = useState('')
  const [attributes, setAttributes] = useState<Array<{ trait_type: string; value: string | number }>>([])
  const [isLoading, setIsLoading] = useState(false)
  const [step, setStep] = useState<'select' | 'metadata' | 'preview' | 'minting'>('select')

  // Загрузка коллекций при монтировании
  useEffect(() => {
    loadCollections()
  }, [])

  // Загрузка коллекций
  const loadCollections = async () => {
    try {
      const allCollections = await nftService.getAllCollections()
      setCollections(allCollections)
      
      // Если есть трек, ищем связанную коллекцию
      if (trackId) {
        const trackCollection = allCollections.find(c => c.category === 'tracks')
        if (trackCollection) {
          setSelectedCollection(trackCollection.id)
        }
      }
    } catch (error) {
      console.error('Error loading collections:', error)
      toast.error('Failed to load collections')
    }
  }

  // Обработка выбора коллекции
  const handleCollectionSelect = (collectionId: string) => {
    setSelectedCollection(collectionId)
    setStep('metadata')
  }

  // Обработка отправки формы
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!connected || !publicKey) {
      toast.error('Please connect your wallet first')
      return
    }

    if (!selectedCollection || !name || !description) {
      toast.error('Please fill in all required fields')
      return
    }

    setIsLoading(true)
    
    try {
      // Создаем метаданные NFT
      const metadata: NFTMetadata = {
        name,
        description,
        image: imageUrl || 'https://via.placeholder.com/300x300',
        animation_url: animationUrl,
        external_url: `https://normaldance.com/nft/${Date.now()}`,
        attributes: attributes || [
          { trait_type: 'Type', value: 'Music NFT' },
          { trait_type: 'Platform', value: 'NORMALDANCE' }
        ]
      }

      // Создаем запрос на минтинг
      const mintRequest: MintRequest = {
        collectionId: selectedCollection,
        metadata,
        price: price * LAMPORTS_PER_SOL, // Конвертируем SOL в lamports
        quantity: quantity || 1,
        toAddress: publicKey.toBase58(),
        royaltyPercentage,
        royaltyAddress: royaltyAddress || publicKey.toBase58(),
        walletAddress: publicKey.toBase58()
      }

      // Показываем предпросмотр
      setStep('preview')
    } catch (error) {
      console.error('Error preparing mint:', error)
      toast.error('Failed to prepare mint')
    } finally {
      setIsLoading(false)
    }
  }

  // Обработка минтинга
  const handleMint = async () => {
    if (!connected || !publicKey) {
      toast.error('Please connect your wallet first')
      return
    }

    setIsLoading(true)
    
    try {
      // Получаем коллекцию
      const collection = collections.find(c => c.id === selectedCollection)
      if (!collection) {
        toast.error('Collection not found')
        return
      }

      // Создаем метаданные NFT
      const metadata: NFTMetadata = {
        name,
        description,
        image: imageUrl || 'https://via.placeholder.com/300x300',
        animation_url: animationUrl,
        external_url: `https://normaldance.com/nft/${Date.now()}`,
        attributes: attributes || [
          { trait_type: 'Type', value: 'Music NFT' },
          { trait_type: 'Platform', value: 'NORMALDANCE' }
        ]
      }

      // Создаем запрос на минтинг
      const mintRequest: MintRequest = {
        collectionId: selectedCollection,
        metadata,
        price: price * LAMPORTS_PER_SOL,
        quantity: quantity || 1,
        toAddress: publicKey.toBase58(),
        royaltyPercentage,
        royaltyAddress: royaltyAddress || publicKey.toBase58(),
        walletAddress: publicKey.toBase58()
      }

      // Выполняем минтинг
      const result = await nftService.mintNFT(mintRequest)
      
      if (result.success) {
        toast.success('NFT minted successfully!')
        onClose?.()
      } else {
        toast.error(result.error || 'Failed to mint NFT')
      }
    } catch (error) {
      console.error('Error minting NFT:', error)
      toast.error('Failed to mint NFT')
    } finally {
      setIsLoading(false)
    }
  }

  // Добавление атрибута
  const addAttribute = () => {
    setAttributes([...attributes, { trait_type: '', value: '' }])
  }

  // Удаление атрибута
  const removeAttribute = (index: number) => {
    setAttributes(attributes.filter((_, i) => i !== index))
  }

  // Обновление атрибута
  const updateAttribute = (index: number, field: 'trait_type' | 'value', value: string) => {
    const newAttributes = [...attributes]
    newAttributes[index][field] = value
    setAttributes(newAttributes)
  }

  // Шаг 1: Выбор коллекции
  if (step === 'select') {
    return (
      <div className="bg-white rounded-lg shadow-lg p-6 max-w-2xl mx-auto">
        <h2 className="text-2xl font-bold mb-6">Select Collection</h2>
        
        {collections.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-gray-500 mb-4">No collections available</p>
            <button 
              onClick={loadCollections}
              className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
            >
              Refresh Collections
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {collections.map((collection) => (
              <div
                key={collection.id}
                className={`border rounded-lg p-4 cursor-pointer transition-all ${
                  selectedCollection === collection.id
                    ? 'border-blue-500 bg-blue-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
                onClick={() => handleCollectionSelect(collection.id)}
              >
                <div className="flex items-center mb-2">
                  <img
                    src={collection.image}
                    alt={collection.name}
                    className="w-12 h-12 rounded-full mr-3"
                  />
                  <div>
                    <h3 className="font-semibold">{collection.name}</h3>
                    <p className="text-sm text-gray-500">{collection.category}</p>
                  </div>
                </div>
                <p className="text-sm text-gray-600 mb-2">{collection.description}</p>
                <div className="flex justify-between text-sm">
                  <span>Supply: {collection.currentSupply}/{collection.maxSupply}</span>
                  <span>Royalty: {collection.royaltyPercentage}%</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    )
  }

  // Шаг 2: Ввод метаданных
  if (step === 'metadata') {
    return (
      <div className="bg-white rounded-lg shadow-lg p-6 max-w-2xl mx-auto">
        <h2 className="text-2xl font-bold mb-6">NFT Metadata</h2>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Name *</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Enter NFT name"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Description *</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Enter NFT description"
              rows={3}
              required
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Image URL</label>
              <input
                type="url"
                value={imageUrl}
                onChange={(e) => setImageUrl(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="https://example.com/image.jpg"
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Animation URL</label>
              <input
                type="url"
                value={animationUrl}
                onChange={(e) => setAnimationUrl(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="https://example.com/video.mp4"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Price (SOL)</label>
              <input
                type="number"
                value={price}
                onChange={(e) => setPrice(parseFloat(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="0.1"
                min="0"
                step="0.01"
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Quantity</label>
              <input
                type="number"
                value={quantity}
                onChange={(e) => setQuantity(parseInt(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="1"
                min="1"
                max="100"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Royalty (%)</label>
              <input
                type="number"
                value={royaltyPercentage}
                onChange={(e) => setRoyaltyPercentage(parseInt(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="10"
                min="0"
                max="50"
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Royalty Address</label>
              <input
                type="text"
                value={royaltyAddress}
                onChange={(e) => setRoyaltyAddress(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Enter wallet address"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Attributes</label>
            <div className="space-y-2">
              {attributes.map((attr, index) => (
                <div key={index} className="flex gap-2">
                  <input
                    type="text"
                    value={attr.trait_type}
                    onChange={(e) => updateAttribute(index, 'trait_type', e.target.value)}
                    className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Trait type"
                  />
                  <input
                    type="text"
                    value={attr.value}
                    onChange={(e) => updateAttribute(index, 'value', e.target.value)}
                    className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Value"
                  />
                  <button
                    type="button"
                    onClick={() => removeAttribute(index)}
                    className="px-3 py-2 bg-red-500 text-white rounded-md hover:bg-red-600"
                  >
                    ×
                  </button>
                </div>
              ))}
              <button
                type="button"
                onClick={addAttribute}
                className="px-3 py-2 bg-gray-500 text-white rounded-md hover:bg-gray-600"
              >
                Add Attribute
              </button>
            </div>
          </div>

          <div className="flex gap-4">
            <button
              type="submit"
              className="flex-1 bg-blue-500 text-white py-2 px-4 rounded-md hover:bg-blue-600 disabled:bg-gray-400"
              disabled={isLoading}
            >
              {isLoading ? 'Preparing...' : 'Continue to Preview'}
            </button>
            <button
              type="button"
              onClick={() => setStep('select')}
              className="flex-1 bg-gray-500 text-white py-2 px-4 rounded-md hover:bg-gray-600"
            >
              Back
            </button>
          </div>
        </form>
      </div>
    )
  }

  // Шаг 3: Предпросмотр
  if (step === 'preview') {
    const collection = collections.find(c => c.id === selectedCollection)
    
    return (
      <div className="bg-white rounded-lg shadow-lg p-6 max-w-2xl mx-auto">
        <h2 className="text-2xl font-bold mb-6">Preview NFT</h2>
        
        <div className="border rounded-lg p-4 mb-6">
          <div className="flex items-center mb-4">
            <img
              src={imageUrl || 'https://via.placeholder.com/300x300'}
              alt={name}
              className="w-24 h-24 rounded-lg mr-4"
            />
            <div>
              <h3 className="text-xl font-bold">{name}</h3>
              <p className="text-gray-600">{description}</p>
              <p className="text-sm text-gray-500">Collection: {collection?.name}</p>
            </div>
          </div>
          
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="font-medium">Price:</span> {price} SOL
            </div>
            <div>
              <span className="font-medium">Quantity:</span> {quantity}
            </div>
            <div>
              <span className="font-medium">Royalty:</span> {royaltyPercentage}%
            </div>
            <div>
              <span className="font-medium">Royalty Address:</span> {royaltyAddress || publicKey?.toBase58()}
            </div>
          </div>
        </div>

        <div className="flex gap-4">
          <button
            onClick={handleMint}
            className="flex-1 bg-green-500 text-white py-2 px-4 rounded-md hover:bg-green-600 disabled:bg-gray-400"
            disabled={isLoading}
          >
            {isLoading ? 'Minting...' : 'Mint NFT'}
          </button>
          <button
            onClick={() => setStep('metadata')}
            className="flex-1 bg-gray-500 text-white py-2 px-4 rounded-md hover:bg-gray-600"
          >
            Back
          </button>
        </div>
      </div>
    )
  }

  return null
}

export default NFTMintingInterface