# NormalDance: Архитектурные диаграммы и схемы

## C4 Architecture Model

### Level 1: System Context
```mermaid
graph TB
    subgraph "External Systems"
        A[Musicians/Artists] 
        B[Music Listeners]
        C[Phantom Wallet]
        D[Solana Blockchain]
        E[IPFS Network]
    end
    
    subgraph "NormalDance Platform"
        F[NormalDance System]
    end
    
    A -->|Upload Music, Create NFTs| F
    B -->|Stream Music, Buy NFTs| F
    F -->|Wallet Integration| C
    F -->|Smart Contracts| D
    F -->|Decentralized Storage| E
    
    classDef external fill:#e1f5fe
    classDef system fill:#c8e6c9
    class A,B,C,D,E external
    class F system
```

### Level 2: Container Diagram
```mermaid
graph TB
    subgraph "NormalDance Platform"
        subgraph "Frontend"
            A[Next.js Web App<br/>Port: 3000<br/>SLA: 99.9%]
        end
        
        subgraph "Backend Services"
            B[API Gateway<br/>Load Balancer<br/>Rate Limiting]
            C[Authentication Service<br/>NextAuth + JWT]
            D[NFT Service<br/>Solana Integration]
            E[Streaming Service<br/>IPFS + CDN]
            F[Payment Service<br/>Crypto Transactions]
        end
        
        subgraph "Data Layer"
            G[PostgreSQL<br/>Primary Database]
            H[Redis Cache<br/>Session + Performance]
            I[IPFS Storage<br/>Music Files + Metadata]
        end
    end
    
    A --> B
    B --> C
    B --> D
    B --> E
    B --> F
    C --> G
    D --> G
    E --> I
    F --> G
    D --> H
    E --> H
```

### Level 3: Component Diagram - NFT Service
```mermaid
graph TB
    subgraph "NFT Service Container"
        A[NFT Controller<br/>REST API Endpoints]
        B[NFT Business Logic<br/>Validation + Rules]
        C[Solana Connector<br/>Blockchain Interface]
        D[Metadata Manager<br/>IPFS Integration]
        E[Royalty Calculator<br/>Revenue Distribution]
    end
    
    subgraph "External Dependencies"
        F[Solana Program<br/>Smart Contract]
        G[IPFS Node<br/>Metadata Storage]
        H[PostgreSQL<br/>NFT Records]
    end
    
    A --> B
    B --> C
    B --> D
    B --> E
    C --> F
    D --> G
    B --> H
```

## Data Flow Architecture

### Music Upload & NFT Creation Flow
```mermaid
sequenceDiagram
    participant A as Artist
    participant W as Web App
    participant API as API Gateway
    participant NFT as NFT Service
    participant IPFS as IPFS Storage
    participant SOL as Solana
    participant DB as Database
    
    A->>W: Upload music file + metadata
    W->>API: POST /api/nft/create
    API->>NFT: Process NFT creation
    NFT->>IPFS: Store music file
    IPFS-->>NFT: Return IPFS hash
    NFT->>IPFS: Store metadata JSON
    IPFS-->>NFT: Return metadata hash
    NFT->>SOL: Create NFT on blockchain
    SOL-->>NFT: Return transaction signature
    NFT->>DB: Save NFT record
    NFT-->>API: Return NFT details
    API-->>W: Success response
    W-->>A: Show created NFT
```

### Music Streaming Flow
```mermaid
sequenceDiagram
    participant L as Listener
    participant W as Web App
    participant CDN as CDN/Cache
    participant API as API Gateway
    participant STREAM as Streaming Service
    participant IPFS as IPFS Storage
    participant DB as Database
    
    L->>W: Request track playback
    W->>CDN: Check cached audio
    alt Cache Hit
        CDN-->>W: Return cached audio
    else Cache Miss
        W->>API: GET /api/stream/{trackId}
        API->>STREAM: Process stream request
        STREAM->>DB: Verify access rights
        STREAM->>IPFS: Fetch audio file
        IPFS-->>STREAM: Return audio stream
        STREAM-->>API: Return stream URL
        API-->>W: Stream URL + metadata
        W->>CDN: Cache audio for future requests
    end
    W-->>L: Play audio stream
```

## Network Architecture

### Docker Network Topology
```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host Network                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Frontend      │    │   Reverse       │                │
│  │   Network       │    │   Proxy         │                │
│  │   172.25.1.0/24 │────│   nginx         │                │
│  │                 │    │   Port: 80,443  │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Backend       │    │   Cache         │                │
│  │   Network       │    │   Network       │                │
│  │   172.25.2.0/24 │────│   172.25.4.0/24 │                │
│  │                 │    │   Redis Cluster │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                                                 │
│  ┌─────────────────┐                                       │
│  │   Database      │                                       │
│  │   Network       │                                       │
│  │   172.25.3.0/24 │                                       │
│  │   PostgreSQL    │                                       │
│  └─────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Security Zones
```
Internet
    │
    ▼
┌─────────────────┐
│   DMZ Zone      │  ← Reverse Proxy, Load Balancer
│   Public Access │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Application     │  ← Web App, API Services
│ Zone            │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Data Zone       │  ← Database, Cache, Storage
│ Restricted      │
└─────────────────┘
```

## Performance Architecture

### Caching Strategy
```mermaid
graph TB
    subgraph "Client Side"
        A[Browser Cache<br/>Static Assets<br/>TTL: 24h]
    end
    
    subgraph "CDN Layer"
        B[CloudFlare CDN<br/>Global Distribution<br/>TTL: 1h]
    end
    
    subgraph "Application Layer"
        C[Redis Cache<br/>API Responses<br/>TTL: 5min]
        D[Application Cache<br/>In-Memory<br/>TTL: 1min]
    end
    
    subgraph "Database Layer"
        E[PostgreSQL<br/>Query Cache<br/>Automatic]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
```

### Load Balancing Strategy
```
                    ┌─────────────────┐
                    │   Load Balancer │
                    │   nginx/HAProxy │
                    └─────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
    ┌───────▼────┐  ┌───────▼────┐  ┌───────▼────┐
    │ App Node 1 │  │ App Node 2 │  │ App Node 3 │
    │ CPU: 70%   │  │ CPU: 65%   │  │ CPU: 72%   │
    │ RAM: 80%   │  │ RAM: 75%   │  │ RAM: 78%   │
    └────────────┘  └────────────┘  └────────────┘
            │               │               │
            └───────────────┼───────────────┘
                            │
                    ┌───────▼────┐
                    │ PostgreSQL │
                    │ Master/Slave│
                    └────────────┘
```

## Monitoring & Observability

### Metrics Collection Architecture
```mermaid
graph TB
    subgraph "Application Layer"
        A[Next.js App<br/>Custom Metrics]
        B[API Services<br/>Performance Metrics]
        C[Database<br/>Query Metrics]
    end
    
    subgraph "Collection Layer"
        D[Prometheus<br/>Metrics Collector]
        E[Grafana<br/>Visualization]
        F[AlertManager<br/>Notifications]
    end
    
    subgraph "Storage Layer"
        G[InfluxDB<br/>Time Series Data]
        H[Elasticsearch<br/>Log Aggregation]
    end
    
    A --> D
    B --> D
    C --> D
    D --> E
    D --> F
    D --> G
    B --> H
```

### Health Check Architecture
```yaml
# Health Check Endpoints
/api/health/live     # Liveness probe
/api/health/ready    # Readiness probe
/api/health/metrics  # Prometheus metrics

# Service Dependencies Check
services:
  - name: postgresql
    endpoint: tcp://postgres:5432
    timeout: 5s
  - name: redis
    endpoint: tcp://redis:6379
    timeout: 3s
  - name: ipfs
    endpoint: http://ipfs:5001/api/v0/version
    timeout: 10s
```

## Deployment Architecture

### Blue/Green Deployment
```
Production Traffic (100%)
         │
    ┌────▼────┐
    │ Router  │
    └────┬────┘
         │
    ┌────▼────┐     ┌─────────┐
    │ Blue    │     │ Green   │
    │ v1.2.3  │     │ v1.2.4  │ ← New version
    │ Active  │     │ Standby │
    └─────────┘     └─────────┘

# Deployment Process:
1. Deploy v1.2.4 to Green environment
2. Run health checks on Green
3. Switch router to Green (0 downtime)
4. Blue becomes new standby
```

### Rollback Strategy
```mermaid
graph TB
    A[Deploy New Version] --> B{Health Check Pass?}
    B -->|Yes| C[Switch Traffic]
    B -->|No| D[Automatic Rollback]
    C --> E{Monitor Metrics}
    E -->|Degradation| F[Immediate Rollback]
    E -->|Stable| G[Success]
    D --> H[Alert Team]
    F --> H
```

## Security Architecture

### Authentication Flow
```mermaid
sequenceDiagram
    participant U as User
    participant W as Web App
    participant A as Auth Service
    participant P as Phantom Wallet
    participant DB as Database
    
    U->>W: Connect Wallet
    W->>P: Request Connection
    P-->>W: Wallet Address
    W->>A: Authenticate with address
    A->>DB: Check user record
    A->>A: Generate JWT token
    A-->>W: Return JWT + user data
    W-->>U: Authenticated session
```

### Data Encryption
```
┌─────────────────────────────────────────────────────────┐
│                 Encryption Layers                       │
├─────────────────────────────────────────────────────────┤
│ Transport Layer: TLS 1.3 (HTTPS)                      │
│ Application Layer: JWT tokens (RS256)                  │
│ Database Layer: AES-256 encryption at rest            │
│ Storage Layer: IPFS content addressing (SHA-256)       │
│ Wallet Layer: Ed25519 signatures (Solana)             │
└─────────────────────────────────────────────────────────┘
```