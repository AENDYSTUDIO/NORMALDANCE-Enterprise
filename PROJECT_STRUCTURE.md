# 🏗️ NORMALDANCE Enterprise Project Structure

```
NORMALDANCE/
├── 📁 .github/                    # GitHub workflows & templates
│   ├── workflows/                 # CI/CD pipelines
│   ├── ISSUE_TEMPLATE/           # Issue templates
│   ├── PULL_REQUEST_TEMPLATE.md  # PR template
│   └── CODEOWNERS               # Code ownership
├── 📁 .vscode/                   # VS Code configuration
├── 📁 apps/                      # Applications
│   ├── web/                      # Next.js web app
│   ├── mobile/                   # React Native app
│   └── api/                      # Standalone API
├── 📁 packages/                  # Shared packages
│   ├── ui/                       # UI components
│   ├── config/                   # Shared configs
│   ├── utils/                    # Utilities
│   └── types/                    # TypeScript types
├── 📁 infrastructure/            # Infrastructure as Code
│   ├── terraform/                # Terraform configs
│   ├── kubernetes/               # K8s manifests
│   ├── docker/                   # Docker configs
│   └── monitoring/               # Monitoring setup
├── 📁 docs/                      # Documentation
│   ├── api/                      # API documentation
│   ├── architecture/             # System architecture
│   ├── deployment/               # Deployment guides
│   └── security/                 # Security policies
├── 📁 tests/                     # Test suites
│   ├── unit/                     # Unit tests
│   ├── integration/              # Integration tests
│   ├── e2e/                      # End-to-end tests
│   └── performance/              # Performance tests
├── 📁 scripts/                   # Automation scripts
├── 📁 security/                  # Security configurations
└── 📁 tools/                     # Development tools
```

## 🎯 Key Principles

- **Monorepo Structure**: Unified codebase with multiple apps
- **Security First**: Security at every layer
- **Type Safety**: Full TypeScript coverage
- **Testing**: 95%+ test coverage
- **Documentation**: Complete enterprise docs
- **Automation**: Full CI/CD pipeline