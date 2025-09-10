import { NextRequest } from 'next/server';
import { GET } from '../test/route';

describe('/api/auth/test', () => {
  it('returns 200 for authenticated user', async () => {
    const request = new NextRequest('http://localhost:3000/api/auth/test', {
      headers: {
        'authorization': 'Bearer valid-token'
      }
    });

    const response = await GET(request);
    expect(response.status).toBe(200);
  });

  it('returns 401 for unauthenticated user', async () => {
    const request = new NextRequest('http://localhost:3000/api/auth/test');
    const response = await GET(request);
    expect(response.status).toBe(401);
  });
});