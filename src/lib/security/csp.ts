export const CSP_POLICY = {
  'default-src': ["'self'"],
  'script-src': ["'self'", "'unsafe-inline'", 'https://vercel.live'],
  'style-src': ["'self'", "'unsafe-inline'"],
  'img-src': ["'self'", 'data:', 'https:'],
  'connect-src': ["'self'", 'https://api.solana.com', 'https://ipfs.io'],
  'font-src': ["'self'"],
  'object-src': ["'none'"],
  'base-uri': ["'self'"],
  'form-action': ["'self'"],
  'frame-ancestors': ["'none'"],
  'upgrade-insecure-requests': []
};

export function generateCSPHeader(): string {
  return Object.entries(CSP_POLICY)
    .map(([key, values]) => `${key} ${values.join(' ')}`)
    .join('; ');
}