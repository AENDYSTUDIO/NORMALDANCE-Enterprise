// server.ts - Next.js Standalone + Socket.IO
import { setupSocket } from '@/lib/socket';
import { createServer } from 'http';
import { Server } from 'socket.io';
import helmet from 'helmet';
import next from 'next';
import express from 'express';

const dev = process.env.NODE_ENV !== 'production';
const currentPort = 3000;
const hostname = '0.0.0.0';

// Custom server with Socket.IO integration
async function createCustomServer() {
  try {
    // Create Next.js app
    const nextApp = next({ 
      dev,
      dir: process.cwd(),
      // In production, use the current directory where .next is located
      conf: dev ? undefined : { distDir: './.next' }
    });

    await nextApp.prepare();
    const handle = nextApp.getRequestHandler();

    // Create HTTP server that will handle both Next.js and Socket.IO
    const server = createServer((req, res) => {
      // Apply helmet security middleware
      helmet({
        contentSecurityPolicy: {
          directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-eval'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
            fontSrc: ["'self'", "https://fonts.gstatic.com"],
            imgSrc: ["'self'", "data:", "https:", "blob:"],
            mediaSrc: ["'self'", "https:", "blob:"],
            connectSrc: ["'self'", "https:", "wss:", "ws:"],
            frameAncestors: ["'none'"]
          }
        },
        crossOriginEmbedderPolicy: false, // Disable for compatibility
        hsts: dev ? false : {
          maxAge: 31536000,
          includeSubDomains: true,
          preload: true
        }
      })(req, res, () => {
        // Skip socket.io requests from Next.js handler
        if (req.url?.startsWith('/api/socketio')) {
          return;
        }
        handle(req, res);
      });
    });

    // Setup Socket.IO
    const io = new Server(server, {
      path: '/api/socketio',
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      }
    });

    // Optional Redis adapter for multi-replica setups
    try {
      // Lazy import to avoid hard dependency in local dev
      const { createAdapter } = await import('@socket.io/redis-adapter') as any
      const Redis = (await import('ioredis')).default
      const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379'
      const pubClient = new Redis(redisUrl)
      const subClient = pubClient.duplicate()
      io.adapter(createAdapter(pubClient, subClient))
      console.log('Socket.IO Redis adapter enabled')
    } catch (e) {
      console.warn('Socket.IO Redis adapter not enabled:', (e as Error)?.message || e)
    }

    setupSocket(io);

    // Start the server
    server.listen(currentPort, hostname, () => {
      console.log(`> Ready on http://${hostname}:${currentPort}`);
      console.log(`> Socket.IO server running at ws://${hostname}:${currentPort}/api/socketio`);
    });

  } catch (err) {
    console.error('Server startup error:', err);
    process.exit(1);
  }
}

// Start the server
createCustomServer();
