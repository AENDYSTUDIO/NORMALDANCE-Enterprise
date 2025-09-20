'use client'

import { lazy, Suspense } from 'react';

const CrossChainWallet = lazy(() => import('@/components/wallet/cross-chain-wallet'));
const RecommendationEngine = lazy(() => import('@/components/recommendations/recommendation-engine'));

export default function HomePage() {

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #1a1a2e, #16213e, #0f3460)',
      color: 'white',
      padding: '2rem',
      fontFamily: 'Arial, sans-serif'
    }}>
      <div style={{ maxWidth: '800px', margin: '0 auto', textAlign: 'center' }}>
        <h1 style={{ fontSize: '4rem', fontWeight: 'bold', marginBottom: '2rem' }}>
          NORMALDANCE
        </h1>
        <p style={{ fontSize: '1.5rem', marginBottom: '3rem', opacity: 0.8 }}>
          Децентрализованная музыкальная платформа на Solana
        </p>
        
        <div style={{
          background: 'rgba(255,255,255,0.1)',
          borderRadius: '20px',
          padding: '2rem',
          marginBottom: '2rem'
        }}>
          <h2 style={{ fontSize: '2rem', marginBottom: '1rem' }}>
            🎵 Web3 музыкальная платформа
          </h2>
          <p style={{ fontSize: '1.2rem', marginBottom: '2rem', opacity: 0.9 }}>
            Загружайте, продавайте и открывайте музыку в Web3 экосистеме
          </p>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
            <div style={{ background: 'rgba(255,255,255,0.05)', borderRadius: '10px', padding: '1rem' }}>
              <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>🎵</div>
              <h3 style={{ fontWeight: 'bold', marginBottom: '0.5rem' }}>Загружайте музыку</h3>
              <p style={{ fontSize: '0.9rem', opacity: 0.8 }}>Загружайте треки в IPFS и продавайте как NFT</p>
            </div>
            <div style={{ background: 'rgba(255,255,255,0.05)', borderRadius: '10px', padding: '1rem' }}>
              <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>💰</div>
              <h3 style={{ fontWeight: 'bold', marginBottom: '0.5rem' }}>Зарабатывайте</h3>
              <p style={{ fontSize: '0.9rem', opacity: 0.8 }}>Получайте донаты и продавайте музыку за SOL</p>
            </div>
            <div style={{ background: 'rgba(255,255,255,0.05)', borderRadius: '10px', padding: '1rem' }}>
              <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>🌐</div>
              <h3 style={{ fontWeight: 'bold', marginBottom: '0.5rem' }}>Децентрализация</h3>
              <p style={{ fontSize: '0.9rem', opacity: 0.8 }}>Полный контроль над вашим контентом</p>
            </div>
          </div>
          
          <div style={{ textAlign: 'center', opacity: 0.7 }}>
            <p style={{ fontSize: '1rem', marginBottom: '1rem' }}>
              Подключите кошелек Phantom для начала работы
            </p>
          </div>
        </div>
        
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          <Suspense fallback={<div className="animate-pulse bg-gray-700 h-64 rounded-lg"></div>}>
            <CrossChainWallet />
          </Suspense>
          <Suspense fallback={<div className="animate-pulse bg-gray-700 h-64 rounded-lg"></div>}>
            <RecommendationEngine />
          </Suspense>
        </div>
        
        <div style={{ textAlign: 'center', opacity: 0.7 }}>
          <p style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>
            🚀 <strong>Статус:</strong> Enhanced with AI, GraphQL, Microservices & Cross-chain
          </p>
        </div>
      </div>
    </div>
  )
}