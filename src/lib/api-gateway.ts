const SERVICES = {
  auth: process.env.AUTH_SERVICE_URL || 'http://localhost:3001',
  music: process.env.MUSIC_SERVICE_URL || 'http://localhost:3002',
  nft: process.env.NFT_SERVICE_URL || 'http://localhost:3003'
};

export async function proxyToService(service: keyof typeof SERVICES, path: string, options: RequestInit = {}) {
  const url = `${SERVICES[service]}${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    }
  });
  return response.json();
}