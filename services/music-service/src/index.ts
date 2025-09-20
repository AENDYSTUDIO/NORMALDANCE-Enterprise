import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/tracks', (req, res) => {
  res.json({ tracks: [], total: 0 });
});

app.post('/tracks', (req, res) => {
  const { title, artist, ipfsHash } = req.body;
  const track = { id: Date.now(), title, artist, ipfsHash, createdAt: new Date() };
  res.json(track);
});

app.get('/tracks/:id', (req, res) => {
  const { id } = req.params;
  res.json({ id, title: 'Sample Track', artist: 'Sample Artist' });
});

const PORT = process.env.PORT || 3002;
app.listen(PORT, () => console.log(`Music service on port ${PORT}`));