# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Build/Test Commands (Non-Obvious)

- **Single test execution**: `npm test -- --testPathPattern="filename.test.ts"` (Jest configured for specific file testing)
- **Mobile app tests**: `cd mobile-app && npm test` (Separate test environment with extensive mocking)
- **Production build**: `npm run build` (Next.js build disabled, uses tsx directly)
- **MCP server**: `npm run mcp:dev` (Uses tsx watch for hot reload)
- **Import checking**: `npm run check:imports` (Validates import paths using tsx)
- **Auto-fix utilities**: `npm run check:detect` (Detects and fixes common issues)
- **Icon auto-fix**: `npm run check:detect:fix-icons` (Automatically fixes icon-related issues)

## Critical Architecture Patterns

- **Custom server setup**: Uses `server.ts` with Socket.IO instead of standard Next.js server
- **Socket.IO path**: Custom `/api/socketio` path, not standard `/socket.io`
- **Wallet integration**: Use custom event emitter system in `src/components/wallet/wallet-adapter.tsx`, not standard wallet-adapter-react patterns
- **Deflationary model**: All token transactions must use `DeflationaryModel` class for automatic 2% burn calculation
- **Database**: Use global Prisma instance from `src/lib/db.ts`, never create new instances
- **TypeScript**: Web3 code intentionally has relaxed types (`noImplicitAny: false`, `no-non-null-assertion: off`)
- **Error handling**: Wallet operations return 0 on error instead of throwing (silent failures)

## Code Style (Project-Specific)

- **ESLint disabled**: All rules intentionally disabled in `eslint.config.mjs` for faster builds
- **TypeScript**: `noImplicitAny: false`, `no-non-null-assertion: off` (relaxed for Web3)
- **Import patterns**: Wallet utilities use custom event system, not standard React patterns
- **Error handling**: Silent failures in wallet operations, return 0 instead of throwing
- **Russian locale**: All SOL/token formatting uses Russian locale conventions
- **TypeScript config**: Web3 code intentionally has relaxed types (`noImplicitAny: false`, `no-non-null-assertion: off`)

## Testing Setup

- **Dual test environments**: Separate Jest configs for main app (`jest.config.js`) and mobile app (`mobile-app/jest.setup.js`)
- **Extensive mocking**: Mobile app mocks all React Native modules, expo libraries, and WebSocket
- **Test timeout**: 30-second timeout for async operations in `jest.config.js`
- **Coverage**: Excludes `__tests__` directories from coverage reports
- **Mobile app mocking**: Extensive mocking of expo-av, react-native-track-player, and all React Native modules

## Web3 Specific

- **Solana programs**: Fixed program IDs in `programs/tracknft/src/lib.rs` - never change these
- **Transaction handling**: Custom transaction creation in `wallet-adapter.tsx`, not standard Solana patterns
- **Token formatting**: Always use Russian locale formatting for SOL amounts in `formatSol()`
- **Fixed program IDs**: NDT_PROGRAM_ID, TRACKNFT_PROGRAM_ID, STAKING_PROGRAM_ID are hardcoded in `wallet-adapter.tsx` - never change
- **Deflationary economics**: 2% burn with 20% to staking rewards, 30% to treasury - configured in `deflationary-model.ts`
- **Global wallet emitter**: Use `walletEmitter` from `wallet-adapter.tsx` for custom event system

## File Storage & CDN

- **IPFS/Filecoin redundancy**: Use custom IPFS/Filecoin redundancy system in `src/lib/ipfs-enhanced.ts`
- **CDN integration**: Automatic fallback to multiple gateways (ipfs.io, pinata.cloud, cloudflare-ipfs.com)
- **File chunking**: Files >10MB automatically chunked in `ipfs-enhanced.ts` with manifest-based reconstruction
- **Health monitoring**: Automated file availability checking across multiple gateways

## MCP Server

- **Development**: Use `tsx watch` for development, standard Node.js for production
- **Custom path**: Model Context Protocol server in `src/mcp/server.ts`
- **Providers**: Music, User, NFT, and Staking context providers
- **Protocol**: Custom `protocol://` URI system (track://, user://, nft://, staking://)

## Special Routes

- **Investor page**: `/invest` - manually updated when metrics change
- **TON Foundation Grant**: `/ton-grant` - ready for $50,000 grant application
- **Telegram Partnership**: `/telegram-partnership` - ready for Mini-App + Stars revenue share
- **Risk Management**: `/risk-management` - active 4-step insurance model