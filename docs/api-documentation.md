# 🔌 API Documentation

## Authentication
All API endpoints require Bearer token authentication.

```bash
Authorization: Bearer <jwt_token>
```

## Endpoints

### Tracks API

#### GET /api/tracks
Get all tracks with pagination.

**Parameters:**
- `page` (number): Page number (default: 1)
- `limit` (number): Items per page (default: 20)
- `genre` (string): Filter by genre

**Response:**
```json
{
  "tracks": [
    {
      "id": "string",
      "title": "string",
      "artistName": "string",
      "genre": "string",
      "duration": "number",
      "playCount": "number"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100
  }
}
```

#### POST /api/tracks
Create new track (requires authentication).

**Body:**
```json
{
  "title": "string (max 255 chars)",
  "genre": "string (max 50 chars)",
  "file": "File (max 50MB)"
}
```

### Security
- All inputs are sanitized
- Rate limiting: 100 requests per 15 minutes
- CORS enabled for allowed origins only