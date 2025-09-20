import { NextRequest, NextResponse } from 'next/server';
import { proxyToService } from '@/lib/api-gateway';
import { AIRecommendationEngine } from '@/lib/ai/recommendation-engine';
import { CrossChainManager } from '@/lib/blockchain/cross-chain';

const aiEngine = new AIRecommendationEngine();
const crossChain = new CrossChainManager();

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const service = searchParams.get('service');
  const action = searchParams.get('action');

  try {
    switch (service) {
      case 'ai':
        if (action === 'recommendations') {
          const userId = searchParams.get('userId') || 'default';
          const preferences = { genres: ['Electronic'], artists: [], playHistory: [] };
          const recommendations = await aiEngine.getRecommendations(userId, preferences);
          return NextResponse.json({ recommendations });
        }
        break;

      case 'crosschain':
        if (action === 'chains') {
          const chains = crossChain.getSupportedChains();
          return NextResponse.json({ chains });
        }
        break;

      case 'music':
        return NextResponse.json(await proxyToService('music', '/tracks'));

      default:
        return NextResponse.json({ error: 'Unknown service' }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json({ error: 'Service error' }, { status: 500 });
  }
}