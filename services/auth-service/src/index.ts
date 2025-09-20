import express from 'express';
import jwt from 'jsonwebtoken';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

app.post('/auth/login', async (req, res) => {
  const { walletAddress } = req.body;
  const token = jwt.sign({ walletAddress }, JWT_SECRET, { expiresIn: '24h' });
  res.json({ token, user: { walletAddress } });
});

app.post('/auth/verify', (req, res) => {
  const { token } = req.body;
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    res.json({ valid: true, user: decoded });
  } catch {
    res.status(401).json({ valid: false });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Auth service on port ${PORT}`));