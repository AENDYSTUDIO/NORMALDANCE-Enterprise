import '@testing-library/jest-dom'

// Mock Next.js modules
jest.mock('next/router', () => ({
  useRouter: () => ({
    push: jest.fn(),
    pop: jest.fn(),
    reload: jest.fn(),
    back: jest.fn(),
    forward: jest.fn(),
    prefetch: jest.fn().mockResolvedValue(undefined),
    query: {},
    asPath: '/',
    route: '/',
    events: {
      on: jest.fn(),
      off: jest.fn(),
      emit: jest.fn(),
    },
    isFallback: false,
  }),
}))

jest.mock('next/image', () => ({
  Image: (props) => {
    return <img {...props} />
  },
}))

jest.mock('next/font/google', () => ({
  Inter: () => ({
    className: 'font-inter',
    style: {},
  }),
}))

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(),
    removeListener: jest.fn(),
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
})

// Mock ResizeObserver
global.ResizeObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))

// Mock IntersectionObserver
global.IntersectionObserver = jest.fn().mockImplementation(() => ({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
}))

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
}
global.localStorage = localStorageMock

// Mock fetch
global.fetch = jest.fn()

// Mock WebSocket
global.WebSocket = jest.fn()

// Mock Request for Next.js API routes
global.Request = class Request {
  constructor(input, init = {}) {
    this.url = typeof input === 'string' ? input : input.toString()
    this.method = init.method || 'GET'
    this.headers = new Map()
    this.body = init.body || null
    if (init.headers) {
      Object.entries(init.headers).forEach(([key, value]) => {
        this.headers.set(key, value)
      })
    }
  }
  
  json() {
    return Promise.resolve(JSON.parse(this.body))
  }

  text() {
    return Promise.resolve(this.body)
  }
}

// Mock console methods to reduce noise during tests
beforeEach(() => {
  jest.spyOn(console, 'log').mockImplementation(() => {})
  jest.spyOn(console, 'warn').mockImplementation(() => {})
  jest.spyOn(console, 'error').mockImplementation(() => {})
  jest.spyOn(console, 'info').mockImplementation(() => {})
})

afterEach(() => {
  jest.restoreAllMocks()
})

// Mock IPFS client - moved to separate file to avoid module resolution issues
jest.mock('./tests/__mocks__/ipfs-http-client', () => ({
  create: jest.fn(() => ({
    add: jest.fn().mockResolvedValue({ cid: 'test-cid' }),
    cat: jest.fn().mockImplementation(async function* () {
      yield new Uint8Array([1, 2, 3])
    }),
    object: {
      stat: jest.fn().mockResolvedValue({ size: 1000 }),
    },
  })),
}))

// Mock the actual ipfs-http-client module
jest.mock('ipfs-http-client', () => ({
  create: jest.fn(() => ({
    add: jest.fn().mockResolvedValue({ cid: 'test-cid' }),
    cat: jest.fn().mockImplementation(async function* () {
      yield new Uint8Array([1, 2, 3])
    }),
    object: {
      stat: jest.fn().mockResolvedValue({ size: 1000 }),
    },
  })),
}))

// Mock Pinata SDK - moved to separate file
jest.mock('pinata-sdk', () => require('./tests/__mocks__/pinata-sdk'))

// Mock fileType - moved to separate file
jest.mock('file-type', () => require('./tests/__mocks__/file-type'))

// Mock mime-types - moved to separate file
jest.mock('mime-types', () => require('./tests/__mocks__/mime-types'))

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
  LineChart: jest.fn().mockImplementation((props) => <div {...props} />),
  Line: jest.fn().mockImplementation((props) => <div {...props} />),
  XAxis: jest.fn().mockImplementation((props) => <div {...props} />),
  YAxis: jest.fn().mockImplementation((props) => <div {...props} />),
  CartesianGrid: jest.fn().mockImplementation((props) => <div {...props} />),
  Tooltip: jest.fn().mockImplementation((props) => <div {...props} />),
  Legend: jest.fn().mockImplementation((props) => <div {...props} />),
  ResponsiveContainer: jest.fn().mockImplementation((props) => <div {...props} />),
  BarChart: jest.fn().mockImplementation((props) => <div {...props} />),
  Bar: jest.fn().mockImplementation((props) => <div {...props} />),
  PieChart: jest.fn().mockImplementation((props) => <div {...props} />),
  Pie: jest.fn().mockImplementation((props) => <div {...props} />),
  Cell: jest.fn().mockImplementation((props) => <div {...props} />),
}))

// Mock framer-motion
jest.mock('framer-motion', () => ({
  motion: {
    div: jest.fn((props) => <div {...props} />),
    button: jest.fn((props) => <button {...props} />),
    img: jest.fn((props) => <img {...props} />),
    span: jest.fn((props) => <span {...props} />),
    h1: jest.fn((props) => <h1 {...props} />),
    h2: jest.fn((props) => <h2 {...props} />),
    h3: jest.fn((props) => <h3 {...props} />),
    p: jest.fn((props) => <p {...props} />),
    a: jest.fn((props) => <a {...props} />),
    input: jest.fn((props) => <input {...props} />),
    textarea: jest.fn((props) => <textarea {...props} />),
    select: jest.fn((props) => <select {...props} />),
    option: jest.fn((props) => <option {...props} />),
    label: jest.fn((props) => <label {...props} />),
    form: jest.fn((props) => <form {...props} />),
    ul: jest.fn((props) => <ul {...props} />),
    li: jest.fn((props) => <li {...props} />),
    svg: jest.fn((props) => <svg {...props} />),
    path: jest.fn((props) => <path {...props} />),
    circle: jest.fn((props) => <circle {...props} />),
    rect: jest.fn((props) => <rect {...props} />),
    polygon: jest.fn((props) => <polygon {...props} />),
    line: jest.fn((props) => <line {...props} />),
    text: jest.fn((props) => <text {...props} />),
    tspan: jest.fn((props) => <tspan {...props} />),
  },
}))

// Mock lucide-react
jest.mock('lucide-react', () => ({
  Play: () => <div>Play</div>,
  Pause: () => <div>Pause</div>,
  SkipForward: () => <div>SkipForward</div>,
  SkipBack: () => <div>SkipBack</div>,
  Volume2: () => <div>Volume2</div>,
  Heart: () => <div>Heart</div>,
  Share: () => <div>Share</div>,
  Download: () => <div>Download</div>,
  MoreHorizontal: () => <div>MoreHorizontal</div>,
  Search: () => <div>Search</div>,
  User: () => <div>User</div>,
  Settings: () => <div>Settings</div>,
  Home: () => <div>Home</div>,
  Music: () => <div>Music</div>,
  Upload: () => <div>Upload</div>,
  Wallet: () => <div>Wallet</div>,
  Star: () => <div>Star</div>,
  Clock: () => <div>Clock</div>,
  Calendar: () => <div>Calendar</div>,
  Users: () => <div>Users</div>,
  TrendingUp: () => <div>TrendingUp</div>,
  TrendingDown: () => <div>TrendingDown</div>,
  BarChart3: () => <div>BarChart3</div>,
  PieChart: () => <div>PieChart</div>,
  Activity: () => <div>Activity</div>,
  Shield: () => <div>Shield</div>,
  Lock: () => <div>Lock</div>,
  Unlock: () => <div>Unlock</div>,
  Key: () => <div>Key</div>,
  Eye: () => <div>Eye</div>,
  EyeOff: () => <div>EyeOff</div>,
  Bell: () => <div>Bell</div>,
  Mail: () => <div>Mail</div>,
  Phone: () => <div>Phone</div>,
  MapPin: () => <div>MapPin</div>,
  Globe: () => <div>Globe</div>,
  Wifi: () => <div>Wifi</div>,
  Battery: () => <div>Battery</div>,
  WifiOff: () => <div>WifiOff</div>,
  Signal: () => <div>Signal</div>,
  Bluetooth: () => <div>Bluetooth</div>,
  Headphones: () => <div>Headphones</div>,
  Mic: () => <div>Mic</div>,
  VolumeX: () => <div>VolumeX</div>,
  Repeat: () => <div>Repeat</div>,
  Shuffle: () => <div>Shuffle</div>,
  List: () => <div>List</div>,
  Grid: () => <div>Grid</div>,
  Filter: () => <div>Filter</div>,
  Sort: () => <div>Sort</div>,
  RefreshCw: () => <div>RefreshCw</div>,
  RotateCcw: () => <div>RotateCcw</div>,
  RotateCw: () => <div>RotateCw</div>,
  Maximize: () => <div>Maximize</div>,
  Minimize: () => <div>Minimize</div>,
  X: () => <div>X</div>,
  Check: () => <div>Check</div>,
  Plus: () => <div>Plus</div>,
  Minus: () => <div>Minus</div>,
  Edit: () => <div>Edit</div>,
  Trash2: () => <div>Trash2</div>,
  Copy: () => <div>Copy</div>,
  File: () => <div>File</div>,
  Folder: () => <div>Folder</div>,
  Image: () => <div>Image</div>,
  Video: () => <div>Video</div>,
  Music2: () => <div>Music2</div>,
  FileText: () => <div>FileText</div>,
  FileCode: () => <div>FileCode</div>,
  FileImage: () => <div>FileImage</div>,
  FileVideo: () => <div>FileVideo</div>,
  FileMusic: () => <div>FileMusic</div>,
  FileSpreadsheet: () => <div>FileSpreadsheet</div>,
  FilePresentation: () => <div>FilePresentation</div>,
  FileArchive: () => <div>FileArchive</div>,
  FilePdf: () => <div>FilePdf</div>,
  FileWord: () => <div>FileWord</div>,
  FileExcel: () => <div>FileExcel</div>,
  FilePowerpoint: () => <div>FilePowerpoint</div>,
  FileUnknown: () => <div>FileUnknown</div>,
  Hash: () => <div>Hash</div>,
  AtSign: () => <div>AtSign</div>,
  DollarSign: () => <div>DollarSign</div>,
  Percent: () => <div>Percent</div>,
  PlusCircle: () => <div>PlusCircle</div>,
  MinusCircle: () => <div>MinusCircle</div>,
  XCircle: () => <div>XCircle</div>,
  CheckCircle: () => <div>CheckCircle</div>,
  AlertCircle: () => <div>AlertCircle</div>,
  AlertTriangle: () => <div>AlertTriangle</div>,
  Info: () => <div>Info</div>,
  HelpCircle: () => <div>HelpCircle</div>,
  AlertOctagon: () => <div>AlertOctagon</div>,
  AlertSquare: () => <div>AlertSquare</div>,
  AlertSquareX: () => <div>AlertSquareX</div>,
  AlertSquareCheck: () => <div>AlertSquareCheck</div>,
  Square: () => <div>Square</div>,
  SquareCheck: () => <div>SquareCheck</div>,
  SquareX: () => <div>SquareX</div>,
  Circle: () => <div>Circle</div>,
  CircleCheck: () => <div>CircleCheck</div>,
  CircleX: () => <div>CircleX</div>,
  Triangle: () => <div>Triangle</div>,
  Pentagon: () => <div>Pentagon</div>,
  Hexagon: () => <div>Hexagon</div>,
  Octagon: () => <div>Octagon</div>,
  Star: () => <div>Star</div>,
  StarHalf: () => <div>StarHalf</div>,
  StarOff: () => <div>StarOff</div>,
  Heart: () => <div>Heart</div>,
  HeartOff: () => <div>HeartOff</div>,
  HeartPulse: () => <div>HeartPulse</div>,
  HeartHandshake: () => <div>HeartHandshake</div>,
  HeartCrack: () => <div>HeartCrack</div>,
  HeartBreak: () => <div>HeartBreak</div>,
  HeartSquare: () => <div>HeartSquare</div>,
  HeartSquareX: () => <div>HeartSquareX</div>,
  HeartSquareCheck: () => <div>HeartSquareCheck</div>,
  HeartCircle: () => <div>HeartCircle</div>,
  HeartCircleX: () => <div>HeartCircleX</div>,
  HeartCircleCheck: () => <div>HeartCircleCheck</div>,
  HeartDot: () => <div>HeartDot</div>,
}))
