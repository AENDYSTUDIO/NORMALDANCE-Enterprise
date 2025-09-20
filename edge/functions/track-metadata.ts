export default async function handler(request: Request) {
  const url = new URL(request.url);
  const trackId = url.searchParams.get('id');
  
  if (!trackId) {
    return new Response('Track ID required', { status: 400 });
  }

  const cacheHeaders = {
    'Cache-Control': 'public, max-age=3600',
    'Content-Type': 'application/json'
  };

  const metadata = {
    id: trackId,
    title: 'Cached Track',
    artist: 'Edge Artist',
    duration: 180,
    cached: true,
    timestamp: Date.now()
  };

  return new Response(JSON.stringify(metadata), {
    headers: cacheHeaders
  });
}