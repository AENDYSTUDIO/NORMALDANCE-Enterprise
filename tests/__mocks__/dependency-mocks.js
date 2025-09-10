const jest = require('jest')
const React = require('react')

// Mock Solana web3
jest.mock('@solana/web3.js', () => ({
  Connection: jest.fn().mockImplementation(() => ({
    getBalance: jest.fn().mockResolvedValue(1000000000),
    getAccountInfo: jest.fn().mockResolvedValue({
      data: Buffer.from('test'),
      executable: false,
      owner: new Uint8Array([1, 2, 3]),
      lamports: 1000000000,
      rentEpoch: 123,
    }),
    getParsedAccountInfo: jest.fn().mockResolvedValue({
      data: {
        parsed: {
          info: {
            mint: 'test-mint',
            supply: 1000000000,
            decimals: 9,
          }
        }
      },
      executable: false,
      owner: new Uint8Array([1, 2, 3]),
      lamports: 1000000000,
      rentEpoch: 123,
    }),
    sendRawTransaction: jest.fn().mockResolvedValue('tx-hash'),
    confirmTransaction: jest.fn().mockResolvedValue({
      slot: 123,
      confirmations: 1,
      err: null,
    }),
    getLatestBlockhash: jest.fn().mockResolvedValue({
      blockhash: 'test-blockhash',
      lastValidBlockHeight: 1000,
    }),
    sendTransaction: jest.fn().mockResolvedValue('tx-hash'),
  })),
  PublicKey: jest.fn().mockImplementation((publicKey) => ({
    toBytes: () => new Uint8Array([1, 2, 3]),
    toString: () => publicKey,
  })),
  Transaction: jest.fn().mockImplementation(() => ({
    add: jest.fn(),
    serialize: jest.fn().mockReturnValue(Buffer.from('test')),
    sign: jest.fn(),
  })),
  SystemProgram: {
    programId: new Uint8Array([1, 2, 3]),
    createAccount: jest.fn(),
    transfer: jest.fn(),
  },
  LAMPORTS_PER_SOL: 1000000000,
  Keypair: jest.fn(),
  sendAndConfirmTransaction: jest.fn(),
  getAssociatedTokenAddress: jest.fn(),
  createAssociatedTokenAccountInstruction: jest.fn(),
  createTransferInstruction: jest.fn(),
  createMint: jest.fn(),
  createMintToInstruction: jest.fn(),
  createAccount: jest.fn(),
  createInitializeMintInstruction: jest.fn(),
  createAssociatedTokenAccount: jest.fn(),
  getAccount: jest.fn(),
  getBalance: jest.fn(),
  clusterApiUrl: jest.fn().mockReturnValue('https://api.devnet.solana.com'),
}))

// Mock wallet adapters
jest.mock('@solana/wallet-adapter-base', () => ({
  Wallet: jest.fn(),
  WalletAdapter: jest.fn(),
  WalletError: jest.fn(),
  WalletNotConnectedError: jest.fn(),
  WalletNotReadyError: jest.fn(),
  WalletDisconnectedError: jest.fn(),
  WalletLoadFailedError: jest.fn(),
  WalletSendTransactionError: jest.fn(),
  WalletSignTransactionError: jest.fn(),
  BaseSignerWalletAdapter: class {
    constructor() {
      this.connect = jest.fn()
      this.disconnect = jest.fn()
      this.signTransaction = jest.fn()
      this.signAllTransactions = jest.fn()
    }
  },
}))

// Mock wallet adapter react
jest.mock('@solana/wallet-adapter-react', () => ({
  useWallet: jest.fn().mockReturnValue({
    connected: true,
    publicKey: new Uint8Array([1, 2, 3]),
    signTransaction: jest.fn().mockResolvedValue({
      serialize: () => Buffer.from('test'),
    }),
    signAllTransactions: jest.fn().mockResolvedValue([
      {
        serialize: () => Buffer.from('test'),
      }
    ]),
    sendTransaction: jest.fn().mockResolvedValue('tx-hash'),
    disconnect: jest.fn(),
  }),
}))

// Mock wallet adapter wallets
jest.mock('@solana/wallet-adapter-wallets', () => ({
  PhantomWallet: jest.fn(),
  SolflareWallet: jest.fn(),
  LedgerWallet: jest.fn(),
  TorusWallet: jest.fn(),
  SlopeWallet: jest.fn(),
}))

jest.mock('@solana/wallet-adapter-phantom', () => ({
  PhantomWalletAdapter: class {
    constructor() {
      this.connect = jest.fn()
      this.disconnect = jest.fn()
      this.signTransaction = jest.fn()
      this.signAllTransactions = jest.fn()
    }
  },
}))

// Mock Anchor
jest.mock('@coral-xyz/anchor', () => ({
  Program: jest.fn().mockImplementation(() => ({
    account: {
      fetch: jest.fn().mockResolvedValue({}),
    },
    methods: {
      initialize: jest.fn(),
      mint: jest.fn(),
    },
  })),
  AnchorProvider: jest.fn().mockImplementation(() => ({
    connection: {
      getBalance: jest.fn().mockResolvedValue(1000000000),
    },
    wallet: {
      publicKey: new Uint8Array([1, 2, 3]),
      signTransaction: jest.fn().mockResolvedValue({
        serialize: () => Buffer.from('test'),
      }),
    },
  })),
  workspace: jest.fn().mockReturnValue({
    program: jest.fn().mockImplementation(() => ({})),
  }),
}))

// Mock Prisma
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    track: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    playlist: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    like: {
      create: jest.fn(),
      delete: jest.fn(),
    },
    comment: {
      create: jest.fn(),
      delete: jest.fn(),
    },
    reward: {
      create: jest.fn(),
    },
    follow: {
      create: jest.fn(),
      delete: jest.fn(),
    },
    playHistory: {
      create: jest.fn(),
    },
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
  })),
}))

// Mock NextAuth
jest.mock('next-auth', () => ({
  getServerSession: jest.fn(),
}))

jest.mock('next-auth/react', () => ({
  useSession: jest.fn(() => ({
    data: null,
    status: 'loading',
  })),
}))

// Mock socket.io
jest.mock('socket.io-client', () => ({
  io: jest.fn().mockReturnValue({
    on: jest.fn(),
    emit: jest.fn(),
    disconnect: jest.fn(),
  }),
}))

// Mock zustand
jest.mock('zustand', () => ({
  create: jest.fn((fn) => {
    const mockStore = {
      getState: jest.fn(),
      setState: jest.fn(),
      subscribe: jest.fn(),
      destroy: jest.fn(),
    }
    return () => mockStore
  }),
}))

// Mock react-toastify
jest.mock('react-toastify', () => ({
  toast: {
    success: jest.fn(),
    error: jest.fn(),
    info: jest.fn(),
    warning: jest.fn(),
  },
  ToastContainer: jest.fn(),
}))

// Mock recharts
jest.mock('recharts', () => ({
  LineChart: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  Line: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  XAxis: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  YAxis: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  CartesianGrid: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  Tooltip: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  Legend: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  ResponsiveContainer: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  BarChart: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  Bar: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  PieChart: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  Pie: jest.fn().mockImplementation((props) => React.createElement('div', props)),
  Cell: jest.fn().mockImplementation((props) => React.createElement('div', props)),
}))

// Mock framer-motion
jest.mock('framer-motion', () => ({
  motion: {
    div: jest.fn((props) => React.createElement('div', props)),
    button: jest.fn((props) => React.createElement('button', props)),
    img: jest.fn((props) => React.createElement('img', props)),
    span: jest.fn((props) => React.createElement('span', props)),
    h1: jest.fn((props) => React.createElement('h1', props)),
    h2: jest.fn((props) => React.createElement('h2', props)),
    h3: jest.fn((props) => React.createElement('h3', props)),
    p: jest.fn((props) => React.createElement('p', props)),
    a: jest.fn((props) => React.createElement('a', props)),
    input: jest.fn((props) => React.createElement('input', props)),
    textarea: jest.fn((props) => React.createElement('textarea', props)),
    select: jest.fn((props) => React.createElement('select', props)),
    option: jest.fn((props) => React.createElement('option', props)),
    label: jest.fn((props) => React.createElement('label', props)),
    form: jest.fn((props) => React.createElement('form', props)),
    ul: jest.fn((props) => React.createElement('ul', props)),
    li: jest.fn((props) => React.createElement('li', props)),
    svg: jest.fn((props) => React.createElement('svg', props)),
    path: jest.fn((props) => React.createElement('path', props)),
    circle: jest.fn((props) => React.createElement('circle', props)),
    rect: jest.fn((props) => React.createElement('rect', props)),
    polygon: jest.fn((props) => React.createElement('polygon', props)),
    line: jest.fn((props) => React.createElement('line', props)),
    text: jest.fn((props) => React.createElement('text', props)),
    tspan: jest.fn((props) => React.createElement('tspan', props)),
  },
}))

// Mock lucide-react
jest.mock('lucide-react', () => ({
  Play: () => React.createElement('div', {}, 'Play'),
  Pause: () => React.createElement('div', {}, 'Pause'),
  SkipForward: () => React.createElement('div', {}, 'SkipForward'),
  SkipBack: () => React.createElement('div', {}, 'SkipBack'),
  Volume2: () => React.createElement('div', {}, 'Volume2'),
  Heart: () => React.createElement('div', {}, 'Heart'),
  Share: () => React.createElement('div', {}, 'Share'),
  Download: () => React.createElement('div', {}, 'Download'),
  MoreHorizontal: () => React.createElement('div', {}, 'MoreHorizontal'),
  Search: () => React.createElement('div', {}, 'Search'),
  User: () => React.createElement('div', {}, 'User'),
  Settings: () => React.createElement('div', {}, 'Settings'),
  Home: () => React.createElement('div', {}, 'Home'),
  Music: () => React.createElement('div', {}, 'Music'),
  Upload: () => React.createElement('div', {}, 'Upload'),
  Wallet: () => React.createElement('div', {}, 'Wallet'),
  Star: () => React.createElement('div', {}, 'Star'),
  Clock: () => React.createElement('div', {}, 'Clock'),
  Calendar: () => React.createElement('div', {}, 'Calendar'),
  Users: () => React.createElement('div', {}, 'Users'),
  TrendingUp: () => React.createElement('div', {}, 'TrendingUp'),
  TrendingDown: () => React.createElement('div', {}, 'TrendingDown'),
  BarChart3: () => React.createElement('div', {}, 'BarChart3'),
  PieChart: () => React.createElement('div', {}, 'PieChart'),
  Activity: () => React.createElement('div', {}, 'Activity'),
  Shield: () => React.createElement('div', {}, 'Shield'),
  Lock: () => React.createElement('div', {}, 'Lock'),
  Unlock: () => React.createElement('div', {}, 'Unlock'),
  Key: () => React.createElement('div', {}, 'Key'),
  Eye: () => React.createElement('div', {}, 'Eye'),
  EyeOff: () => React.createElement('div', {}, 'EyeOff'),
  Bell: () => React.createElement('div', {}, 'Bell'),
  Mail: () => React.createElement('div', {}, 'Mail'),
  Phone: () => React.createElement('div', {}, 'Phone'),
  MapPin: () => React.createElement('div', {}, 'MapPin'),
  Globe: () => React.createElement('div', {}, 'Globe'),
  Wifi: () => React.createElement('div', {}, 'Wifi'),
  Battery: () => React.createElement('div', {}, 'Battery'),
  WifiOff: () => React.createElement('div', {}, 'WifiOff'),
  Signal: () => React.createElement('div', {}, 'Signal'),
  Bluetooth: () => React.createElement('div', {}, 'Bluetooth'),
  Headphones: () => React.createElement('div', {}, 'Headphones'),
  Mic: () => React.createElement('div', {}, 'Mic'),
  VolumeX: () => React.createElement('div', {}, 'VolumeX'),
  Repeat: () => React.createElement('div', {}, 'Repeat'),
  Shuffle: () => React.createElement('div', {}, 'Shuffle'),
  List: () => React.createElement('div', {}, 'List'),
  Grid: () => React.createElement('div', {}, 'Grid'),
  Filter: () => React.createElement('div', {}, 'Filter'),
  Sort: () => React.createElement('div', {}, 'Sort'),
  RefreshCw: () => React.createElement('div', {}, 'RefreshCw'),
  RotateCcw: () => React.createElement('div', {}, 'RotateCcw'),
  RotateCw: () => React.createElement('div', {}, 'RotateCw'),
  Maximize: () => React.createElement('div', {}, 'Maximize'),
  Minimize: () => React.createElement('div', {}, 'Minimize'),
  X: () => React.createElement('div', {}, 'X'),
  Check: () => React.createElement('div', {}, 'Check'),
  Plus: () => React.createElement('div', {}, 'Plus'),
  Minus: () => React.createElement('div', {}, 'Minus'),
  Edit: () => React.createElement('div', {}, 'Edit'),
  Trash2: () => React.createElement('div', {}, 'Trash2'),
  Copy: () => React.createElement('div', {}, 'Copy'),
  File: () => React.createElement('div', {}, 'File'),
  Folder: () => React.createElement('div', {}, 'Folder'),
  Image: () => React.createElement('div', {}, 'Image'),
  Video: () => React.createElement('div', {}, 'Video'),
  Music2: () => React.createElement('div', {}, 'Music2'),
  FileText: () => React.createElement('div', {}, 'FileText'),
  FileCode: () => React.createElement('div', {}, 'FileCode'),
  FileImage: () => React.createElement('div', {}, 'FileImage'),
  FileVideo: () => React.createElement('div', {}, 'FileVideo'),
  FileMusic: () => React.createElement('div', {}, 'FileMusic'),
  FileSpreadsheet: () => React.createElement('div', {}, 'FileSpreadsheet'),
  FilePresentation: () => React.createElement('div', {}, 'FilePresentation'),
  FileArchive: () => React.createElement('div', {}, 'FileArchive'),
  FilePdf: () => React.createElement('div', {}, 'FilePdf'),
  FileWord: () => React.createElement('div', {}, 'FileWord'),
  FileExcel: () => React.createElement('div', {}, 'FileExcel'),
  FilePowerpoint: () => React.createElement('div', {}, 'FilePowerpoint'),
  FileUnknown: () => React.createElement('div', {}, 'FileUnknown'),
  Hash: () => React.createElement('div', {}, 'Hash'),
  AtSign: () => React.createElement('div', {}, 'AtSign'),
  DollarSign: () => React.createElement('div', {}, 'DollarSign'),
  Percent: () => React.createElement('div', {}, 'Percent'),
  PlusCircle: () => React.createElement('div', {}, 'PlusCircle'),
  MinusCircle: () => React.createElement('div', {}, 'MinusCircle'),
  XCircle: () => React.createElement('div', {}, 'XCircle'),
  CheckCircle: () => React.createElement('div', {}, 'CheckCircle'),
  AlertCircle: () => React.createElement('div', {}, 'AlertCircle'),
  AlertTriangle: () => React.createElement('div', {}, 'AlertTriangle'),
  Info: () => React.createElement('div', {}, 'Info'),
  HelpCircle: () => React.createElement('div', {}, 'HelpCircle'),
  AlertOctagon: () => React.createElement('div', {}, 'AlertOctagon'),
  AlertSquare: () => React.createElement('div', {}, 'AlertSquare'),
  AlertSquareX: () => React.createElement('div', {}, 'AlertSquareX'),
  AlertSquareCheck: () => React.createElement('div', {}, 'AlertSquareCheck'),
  Square: () => React.createElement('div', {}, 'Square'),
  SquareCheck: () => React.createElement('div', {}, 'SquareCheck'),
  SquareX: () => React.createElement('div', {}, 'SquareX'),
  Circle: () => React.createElement('div', {}, 'Circle'),
  CircleCheck: () => React.createElement('div', {}, 'CircleCheck'),
  CircleX: () => React.createElement('div', {}, 'CircleX'),
  Triangle: () => React.createElement('div', {}, 'Triangle'),
  Pentagon: () => React.createElement('div', {}, 'Pentagon'),
  Hexagon: () => React.createElement('div', {}, 'Hexagon'),
  Octagon: () => React.createElement('div', {}, 'Octagon'),
  Star: () => React.createElement('div', {}, 'Star'),
  StarHalf: () => React.createElement('div', {}, 'StarHalf'),
  StarOff: () => React.createElement('div', {}, 'StarOff'),
  Heart: () => React.createElement('div', {}, 'Heart'),
  HeartOff: () => React.createElement('div', {}, 'HeartOff'),
  HeartPulse: () => React.createElement('div', {}, 'HeartPulse'),
  HeartHandshake: () => React.createElement('div', {}, 'HeartHandshake'),
  HeartCrack: () => React.createElement('div', {}, 'HeartCrack'),
  HeartBreak: () => React.createElement('div', {}, 'HeartBreak'),
  HeartSquare: () => React.createElement('div', {}, 'HeartSquare'),
  HeartSquareX: () => React.createElement('div', {}, 'HeartSquareX'),
  HeartSquareCheck: () => React.createElement('div', {}, 'HeartSquareCheck'),
  HeartCircle: () => React.createElement('div', {}, 'HeartCircle'),
  HeartCircleX: () => React.createElement('div', {}, 'HeartCircleX'),
  HeartCircleCheck: () => React.createElement('div', {}, 'HeartCircleCheck'),
  HeartDot: () => React.createElement('div', {}, 'HeartDot'),
}))