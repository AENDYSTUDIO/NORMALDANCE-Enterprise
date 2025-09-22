# 🏗️ Архитектурная схема Telegram Mini-App MVP Normal Dance

## 📊 Общая архитектура

```mermaid
graph TB
    subgraph "Telegram Mini-App"
        A[Telegram Web App]
        B[Telegram SDK]
        C[Mobile UI]
    end

    subgraph "Next.js Backend"
        D[API Routes]
        E[Supabase DB]
        F[IPFS Storage]
        G[Authentication]
    end

    subgraph "Web3 Components"
        H[Solana Wallet]
        I[Phantom Integration]
        J[SOL Donations]
        K[Smart Contracts]
    end

    subgraph "External Services"
        L[Pinata IPFS]
        M[Telegram Bot API]
        N[Sentry Monitoring]
        O[Google Analytics]
    end

    A --> B
    B --> C
    A --> D
    D --> E
    D --> F
    D --> G
    G --> H
    H --> I
    J --> K
    F --> L
    M --> A
    D --> N
    D --> O

    style A fill:#e1f5fe
    style D fill:#f3e5f5
    style H fill:#e8f5e8
    style L fill:#fff3e0
```

## 🔄 Поток данных

### 1. Пользовательский сценарий

```mermaid
sequenceDiagram
    participant U as User
    participant T as Telegram Mini-App
    participant B as Next.js Backend
    participant W as Solana Wallet
    participant S as IPFS Storage

    U->>T: Open Mini-App
    T->>B: Request user data
    B->>T: Return user profile
    T->>U: Show main interface

    U->>T: Select track
    T->>B: Request audio stream
    B->>S: Fetch from IPFS
    S->>B: Return audio URL
    B->>T: Stream audio
    T->>U: Play music

    U->>T: Click donate
    T->>W: Connect wallet
    W->>T: Wallet connected
    T->>B: Process SOL transfer
    B->>W: Send transaction
    W->>B: Transaction confirmed
    B->>T: Donation successful
    T->>U: Show confirmation
```

### 2. Загрузка трека артистом

```mermaid
sequenceDiagram
    participant A as Artist
    participant T as Telegram Mini-App
    participant B as Next.js Backend
    participant I as IPFS Upload
    participant S as Supabase

    A->>T: Upload track
    T->>B: Upload request
    B->>I: Upload to IPFS
    I->>B: Return CID
    B->>S: Save track metadata
    S->>B: Save confirmation
    B->>T: Upload complete
    T->>A: Show success
```

## 🎯 Компонентная архитектура

### Frontend компоненты

```mermaid
graph TD
    A[App Component] --> B[Auth Component]
    A --> C[Player Component]
    A --> D[Library Component]
    A --> E[Profile Component]
    A --> F[Upload Component]
    A --> G[Donate Component]

    B --> H[Wallet Connection]
    C --> I[Audio Controls]
    C --> J[Progress Bar]
    D --> K[Track List]
    E --> L[User Info]
    F --> M[File Upload]
    G --> N[SOL Transfer]
```

### Backend API endpoints

```mermaid
graph LR
    A[API Gateway] --> B[/api/auth]
    A --> C[/api/tracks]
    A --> D[/api/stream]
    A --> E[/api/upload]
    A --> F[/api/donate]
    A --> G[/api/users]

    B --> H[Authentication]
    C --> I[Track Management]
    D --> J[Audio Streaming]
    E --> K[File Upload]
    F --> L[Payment Processing]
    G --> M[User Management]
```

## 📱 Mobile-first дизайн

### Адаптация для Telegram Mini-App

```mermaid
graph TB
    subgraph "Desktop Design"
        A[Full Sidebar]
        B[Large Player]
        C[Complex Navigation]
    end

    subgraph "Mobile Design"
        D[Bottom Navigation]
        E[Compact Player]
        F[Swipe Gestures]
        G[Touch-friendly UI]
    end

    A --> D
    B --> E
    C --> F
    C --> G
```

## 🔐 Безопасность и мониторинг

### Security Flow

```mermaid
graph TD
    A[User Request] --> B[Rate Limiting]
    B --> C[Authentication]
    C --> D[Authorization]
    D --> E[Input Validation]
    E --> F[Business Logic]
    F --> G[Response Sanitization]
    G --> H[Logging]

    style B fill:#ffebee
    style C fill:#e8f5e8
    style D fill:#fff3e0
    style E fill:#e3f2fd
```

### Monitoring Architecture

```mermaid
graph LR
    A[Mini-App] --> B[Sentry]
    A --> C[Google Analytics]
    B --> D[Error Tracking]
    C --> E[User Analytics]
    D --> F[Alerts]
    E --> G[Reports]
```

## 🚀 Deployment Pipeline

### CI/CD Flow

```mermaid
graph TB
    A[Code Commit] --> B[GitHub Actions]
    B --> C[TypeScript Check]
    C --> D[Linting]
    D --> E[Testing]
    E --> F[Build]
    F --> G[Deploy to Vercel]
    G --> H[Health Check]
    H --> I[Production]

    style B fill:#e8f5e8
    style G fill:#e3f2fd
    style I fill:#fff3e0
```

## 📊 Data Flow Architecture

### Database Schema

```mermaid
erDiagram
    USERS {
        string id PK
        string wallet_address
        string username
        string avatar_url
        timestamp created_at
        timestamp updated_at
    }

    TRACKS {
        string id PK
        string title
        string artist_id FK
        string ipfs_cid
        string duration
        string genre
        timestamp created_at
        timestamp updated_at
    }

    PLAYLISTS {
        string id PK
        string name
        string user_id FK
        timestamp created_at
    }

    PLAYLIST_TRACKS {
        string playlist_id FK
        string track_id FK
        integer position
    }

    DONATIONS {
        string id PK
        string donor_id FK
        string artist_id FK
        string track_id FK
        decimal amount
        string transaction_hash
        timestamp created_at
    }

    USERS ||--o{ TRACKS : creates
    USERS ||--o{ PLAYLISTS : owns
    USERS ||--o{ DONATIONS : makes
    TRACKS ||--o{ PLAYLIST_TRACKS : included_in
    TRACKS ||--o{ DONATIONS : receives
    PLAYLISTS ||--o{ PLAYLIST_TRACKS : contains
```

## 🎯 Performance Optimization

### Caching Strategy

```mermaid
graph TD
    A[User Request] --> B[Cache Check]
    B -->|Hit| C[Return Cached Response]
    B -->|Miss| D[Process Request]
    D --> E[Cache Response]
    E --> F[Return Response]

    style B fill:#fff3e0
    style C fill:#e8f5e8
    style E fill:#e8f5e8
```

### Load Balancing

```mermaid
graph LR
    A[Telegram Mini-App] --> B[Vercel Edge]
    B --> C[Primary Region]
    B --> D[Fallback Region]
    C --> E[Supabase]
    D --> E
    C --> F[IPFS]
    D --> F
```

Эта архитектурная схема обеспечивает основу для создания масштабируемого, безопасного и производительного Telegram Mini-App MVP для Normal Dance.
