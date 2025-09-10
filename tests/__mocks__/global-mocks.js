const jest = require('jest')
const React = require('react')

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
    return React.createElement('img', props)
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