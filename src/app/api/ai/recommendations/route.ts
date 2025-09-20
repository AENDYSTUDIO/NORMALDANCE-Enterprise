import { NextRequest, NextResponse } from 'next/server';
import { AIRecommendationEngine } from '@/lib/ai/recommendation-engine';

const engine = new AIRecommendationEngine();

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = searchParams.get('userId');
  
  if (!userId) {
    return NextResponse.json({ error: 'User ID required' }, { status: 400 });
  }

  const preferences = {
    genres: ['Electronic', 'Ambient'],
    artists: ['AI Artist'],
    playHistory: ['1', '2']
  };

  const recommendations = await engine.getRecommendations(userId, preferences);
  
  return NextResponse.json({ recommendations });
}

export async function POST(request: NextRequest) {
  const { userId, trackId, interaction } = await request.json();
  
  await engine.updateUserProfile(userId, trackId, interaction);
  
  return NextResponse.json({ success: true });
}