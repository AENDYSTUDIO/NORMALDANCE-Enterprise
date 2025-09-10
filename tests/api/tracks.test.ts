import { NextRequest } from 'next/server';
import { GET, PUT } from '@/app/api/tracks/[id]/route';

jest.mock('@/lib/db', () => ({
  db: {
    track: {
      findUnique: jest.fn(),
      update: jest.fn(),
    }
  }
}));

describe('/api/tracks/[id]', () => {
  describe('GET', () => {
    it('should return track when found', async () => {
      const mockTrack = {
        id: '1',
        title: 'Test Track',
        artist: { username: 'testuser' }
      };
      
      require('@/lib/db').db.track.findUnique.mockResolvedValue(mockTrack);
      
      const request = new NextRequest('http://localhost/api/tracks/1');
      const response = await GET(request, { params: { id: '1' } });
      const data = await response.json();
      
      expect(response.status).toBe(200);
      expect(data).toEqual(mockTrack);
    });

    it('should return 404 when track not found', async () => {
      require('@/lib/db').db.track.findUnique.mockResolvedValue(null);
      
      const request = new NextRequest('http://localhost/api/tracks/999');
      const response = await GET(request, { params: { id: '999' } });
      
      expect(response.status).toBe(404);
    });
  });
});