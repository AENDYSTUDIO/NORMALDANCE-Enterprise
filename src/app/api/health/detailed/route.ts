import { NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET() {
  const checks = {
    database: false,
    redis: false,
    ipfs: false,
    solana: false
  };

  try {
    await db.$queryRaw`SELECT 1`;
    checks.database = true;
  } catch {}

  try {
    const response = await fetch(process.env.SOLANA_RPC_URL!, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'getHealth' }),
      signal: AbortSignal.timeout(5000)
    });
    checks.solana = response.ok;
  } catch {}

  const allHealthy = Object.values(checks).every(Boolean);
  
  return NextResponse.json({
    status: allHealthy ? 'healthy' : 'unhealthy',
    checks,
    timestamp: new Date().toISOString()
  }, { status: allHealthy ? 200 : 503 });
}