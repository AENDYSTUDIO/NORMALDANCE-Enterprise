'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle, Badge, Button } from '@/components/ui'
import { Music, Play, Heart, TrendingUp, Users, Clock, Star } from '@/components/icons'
import { AIRecommendationEngine } from '@/lib/ai/recommendation-engine'

interface Track {
  id: string
  title: string
  artist: string
  genre: string
  bpm: number
  similarity: number
  playCount: number
  rating: number
  collaborativeScore?: number
}

interface UserListeningHistory {
  trackId: string
  playCount: number
  rating: number
  timestamp: Date
}

interface CollaborativeRecommendation {
  trackId: string
  score: number
  reason: string
}

const aiEngine = new AIRecommendationEngine();

export function RecommendationEngine() {
  const [recommendations, setRecommendations] = useState<Track[]>([])
  const [loading, setLoading] = useState(false)
  const [activeTab, setActiveTab] = useState<'personal' | 'collaborative' | 'trending'>('personal')
  const [listeningHistory, setListeningHistory] = useState<UserListeningHistory[]>([])
  const [collaborativeRecs, setCollaborativeRecs] = useState<CollaborativeRecommendation[]>([])

  useEffect(() => {
    const mockHistory: UserListeningHistory[] = [
      { trackId: '1', playCount: 5, rating: 4.5, timestamp: new Date('2024-01-15') },
      { trackId: '2', playCount: 3, rating: 4.0, timestamp: new Date('2024-01-16') },
      { trackId: '3', playCount: 8, rating: 5.0, timestamp: new Date('2024-01-17') },
      { trackId: '4', playCount: 2, rating: 3.5, timestamp: new Date('2024-01-18') }
    ]
    setListeningHistory(mockHistory)
  }, [])

  const generatePersonalRecommendations = async (): Promise<Track[]> => {
    const avgBpm = 120
    const mockTracks: Track[] = [
      { id: '5', title: 'Neon Nights', artist: 'Synthwave Master', genre: 'Synthwave', bpm: 125, similarity: 92, playCount: 150, rating: 4.8 },
      { id: '6', title: 'Deep Space', artist: 'Cosmic Beats', genre: 'Electronic', bpm: 110, similarity: 88, playCount: 89, rating: 4.6 },
      { id: '7', title: 'Urban Jungle', artist: 'City Rhythms', genre: 'Hip Hop', bpm: 135, similarity: 85, playCount: 234, rating: 4.4 }
    ]
    return mockTracks
  }

  const generateCollaborativeRecommendations = async (): Promise<CollaborativeRecommendation[]> => {
    const collaborativeRecs: CollaborativeRecommendation[] = [
      { trackId: '8', score: 0.92, reason: 'Похоже на то, что слушают пользователи с похожими вкусами' },
      { trackId: '9', score: 0.87, reason: 'Популярно среди вашей музыкальной группы' },
      { trackId: '10', score: 0.79, reason: 'Рекомендовано на основе совместного прослушивания' }
    ]
    return collaborativeRecs
  }

  const generateTrendingRecommendations = async (): Promise<Track[]> => {
    const trendingTracks: Track[] = [
      { id: '11', title: 'Viral Hit 2024', artist: 'Rising Star', genre: 'Pop', bpm: 125, similarity: 0, playCount: 15420, rating: 4.9 },
      { id: '12', title: 'Underground Gem', artist: 'Hidden Talent', genre: 'Alternative', bpm: 110, similarity: 0, playCount: 8920, rating: 4.7 },
      { id: '13', title: 'Club Anthem', artist: 'DJ Night', genre: 'EDM', bpm: 130, similarity: 0, playCount: 12340, rating: 4.6 }
    ]
    return trendingTracks
  }

  const generateRecommendations = async () => {
    setLoading(true)
    
    try {
      let newRecommendations: Track[] = []
      let newCollaborativeRecs: CollaborativeRecommendation[] = []

      switch (activeTab) {
        case 'personal':
          newRecommendations = await generatePersonalRecommendations()
          break
        case 'collaborative':
          newCollaborativeRecs = await generateCollaborativeRecommendations()
          setCollaborativeRecs(newCollaborativeRecs)
          break
        case 'trending':
          newRecommendations = await generateTrendingRecommendations()
          break
      }

      setRecommendations(newRecommendations)
    } catch (error) {
      console.error('Error generating recommendations:', error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    generateRecommendations()
  }, [activeTab])

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <TrendingUp className="h-5 w-5" />
          AI Рекомендации
        </CardTitle>
        <div className="flex gap-2 mt-4">
          <Button 
            variant={activeTab === 'personal' ? 'default' : 'outline'} 
            size="sm"
            onClick={() => setActiveTab('personal')}
          >
            <Star className="h-4 w-4 mr-1" />
            Персональные
          </Button>
          <Button 
            variant={activeTab === 'collaborative' ? 'default' : 'outline'} 
            size="sm"
            onClick={() => setActiveTab('collaborative')}
          >
            <Users className="h-4 w-4 mr-1" />
            Коллаборативные
          </Button>
          <Button 
            variant={activeTab === 'trending' ? 'default' : 'outline'} 
            size="sm"
            onClick={() => setActiveTab('trending')}
          >
            <TrendingUp className="h-4 w-4 mr-1" />
            Тренды
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {loading ? (
          <div className="text-center py-8">
            <div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full mx-auto mb-2" />
            <p>Анализируем ваши предпочтения...</p>
          </div>
        ) : activeTab === 'collaborative' ? (
          collaborativeRecs.map((rec, index) => (
            <div key={index} className="flex items-center justify-between p-3 bg-muted rounded-lg">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                  <Users className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="font-medium">Трек #{rec.trackId}</h4>
                  <p className="text-sm text-muted-foreground">{rec.reason}</p>
                  <div className="flex gap-2 mt-1">
                    <Badge variant="secondary" className="text-xs">
                      Совпадение: {Math.round(rec.score * 100)}%
                    </Badge>
                  </div>
                </div>
              </div>
              <div className="flex gap-2">
                <Button size="sm" variant="ghost">
                  <Heart className="h-4 w-4" />
                </Button>
                <Button size="sm">
                  <Play className="h-4 w-4" />
                </Button>
              </div>
            </div>
          ))
        ) : (
          recommendations.map(track => (
            <div key={track.id} className="flex items-center justify-between p-3 bg-muted rounded-lg">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                  <Music className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="font-medium">{track.title}</h4>
                  <p className="text-sm text-muted-foreground">{track.artist}</p>
                  <div className="flex gap-2 mt-1">
                    <Badge variant="secondary">{track.genre}</Badge>
                    <Badge variant="outline">{track.similarity}% совпадение</Badge>
                    <Badge variant="outline">{track.bpm} BPM</Badge>
                  </div>
                </div>
              </div>
              <div className="flex gap-2">
                <Button size="sm" variant="ghost"><Heart className="h-4 w-4" /></Button>
                <Button size="sm"><Play className="h-4 w-4" /></Button>
              </div>
            </div>
          ))
        )}
      </CardContent>
    </Card>
  )
}