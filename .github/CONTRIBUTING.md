# 🤝 Contributing to NORMALDANCE

Thank you for your interest in contributing to NORMALDANCE! This document provides guidelines and information for contributors.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Community Guidelines](#community-guidelines)

## 📜 Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to conduct@normaldance.com.

## 🚀 Getting Started

### Prerequisites

- Node.js 18.x or higher
- pnpm 8.x or higher
- Git
- Basic knowledge of React, TypeScript, and Next.js

### Development Setup

1. **Fork the repository**

   ```bash
   # Click the "Fork" button on GitHub
   ```

2. **Clone your fork**

   ```bash
   git clone https://github.com/YOUR_USERNAME/NORMALDANCE-Enterprise.git
   cd NORMALDANCE-Enterprise
   ```

3. **Add upstream remote**

   ```bash
   git remote add upstream https://github.com/normaldance/NORMALDANCE-Enterprise.git
   ```

4. **Install dependencies**

   ```bash
   pnpm install
   ```

5. **Setup environment**

   ```bash
   cp env.example .env.local
   # Edit .env.local with your configuration
   ```

6. **Setup database**

   ```bash
   pnpm db:setup
   ```

7. **Start development server**

   ```bash
   pnpm dev
   ```

## 🔄 Development Process

### Branch Strategy

We use [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) for our branching strategy:

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - Feature development branches
- `bugfix/*` - Bug fix branches
- `hotfix/*` - Critical production fixes
- `release/*` - Release preparation branches

### Creating a Branch

```bash
# For new features
git checkout -b feature/amazing-feature

# For bug fixes
git checkout -b bugfix/fix-issue-123

# For hotfixes
git checkout -b hotfix/critical-fix
```

### Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

**Examples:**

```bash
feat(auth): add OAuth2 integration
fix(api): resolve rate limiting issue
docs(readme): update installation instructions
```

## 🎨 Coding Standards

### TypeScript

- Use TypeScript for all new code
- Enable strict mode
- Use proper type definitions
- Avoid `any` type unless absolutely necessary
- Use interfaces for object shapes
- Use enums for constants

### React

- Use functional components with hooks
- Use TypeScript for component props
- Follow the single responsibility principle
- Use proper error boundaries
- Implement proper loading states

### Code Style

- Use Prettier for code formatting
- Follow ESLint rules
- Use meaningful variable and function names
- Write self-documenting code
- Add comments for complex logic

### File Organization

```
src/
├── components/          # Reusable UI components
│   ├── ui/             # Basic UI components
│   ├── forms/          # Form components
│   └── layout/         # Layout components
├── lib/                # Utility functions
├── hooks/              # Custom React hooks
├── types/              # TypeScript type definitions
└── styles/             # Global styles
```

## 🧪 Testing Guidelines

### Test Types

1. **Unit Tests** - Test individual functions and components
2. **Integration Tests** - Test component interactions
3. **E2E Tests** - Test complete user workflows
4. **Performance Tests** - Test application performance

### Writing Tests

```typescript
// Example unit test
describe("UserService", () => {
  it("should create a new user", async () => {
    const userData = { name: "John Doe", email: "john@example.com" };
    const user = await UserService.create(userData);

    expect(user).toBeDefined();
    expect(user.name).toBe(userData.name);
    expect(user.email).toBe(userData.email);
  });
});
```

### Test Requirements

- All new features must have tests
- Maintain >90% code coverage
- Tests must be fast and reliable
- Use descriptive test names
- Test both success and error cases

## 🔄 Pull Request Process

### Before Submitting

1. **Update your branch**

   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```

2. **Run tests**

   ```bash
   pnpm test
   pnpm lint
   pnpm type-check
   ```

3. **Update documentation** if needed

4. **Add tests** for new functionality

### Pull Request Template

Use the provided [PR template](.github/pull_request_template.md) when creating pull requests.

### Review Process

1. **Automated Checks** - CI/CD pipeline runs automatically
2. **Code Review** - At least one team member reviews
3. **Testing** - All tests must pass
4. **Documentation** - Update docs if needed
5. **Approval** - Maintainer approval required

### PR Guidelines

- Keep PRs focused and small
- Use descriptive titles and descriptions
- Link related issues
- Add screenshots for UI changes
- Ensure all checks pass

## 🐛 Issue Guidelines

### Bug Reports

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) and include:

- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Screenshots if applicable

### Feature Requests

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml) and include:

- Problem statement
- Proposed solution
- Use cases
- Mockups or examples

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements to documentation
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `priority: high` - High priority issue
- `priority: low` - Low priority issue

## 👥 Community Guidelines

### Communication

- Be respectful and inclusive
- Use clear and concise language
- Provide constructive feedback
- Help others learn and grow

### Getting Help

- Check existing issues and discussions
- Use the appropriate channels (GitHub, Discord, etc.)
- Provide context and details
- Be patient with responses

### Recognition

Contributors are recognized in:

- README.md contributors section
- Release notes
- Community highlights
- Special contributor badges

## 🔧 Development Tools

### Recommended VS Code Extensions

- ES7+ React/Redux/React-Native snippets
- TypeScript Importer
- Prettier - Code formatter
- ESLint
- GitLens
- Auto Rename Tag
- Bracket Pair Colorizer

### VS Code Settings

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.preferences.importModuleSpecifier": "relative"
}
```

## 📚 Resources

### Internal Documentation

- [Security Architecture](docs/security/security-architecture.md)
- [Secure Coding Guidelines](docs/security/secure-coding.md)
- [Incident Response Plan](docs/security/incident-response.md)
- [Compliance Checklist](docs/security/compliance-checklist.md)

### External Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Controls](https://www.cisecurity.org/controls/)
- [OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)

## 🚨 Incident Response

### Security Incident Classification

| Level | Description | Response |
|-------|-------------|----------|
| **P0** | Critical security breach | Immediate response |
| **P1** | High severity incident | Response within 1 hour |
| **P2** | Medium severity incident | Response within 4 hours |
| **P3** | Low severity incident | Response within 24 hours |

### Incident Response Team

- **Security Lead** - Overall incident coordination
- **Technical Lead** - Technical investigation and remediation
- **Communications Lead** - Public communication and notifications
- **Legal Counsel** - Legal and compliance guidance

### Contact Information

- **Security Team**: security@normaldance.com
- **Emergency Contact**: +1-XXX-XXX-XXXX
- **Legal Team**: legal@normaldance.com

## 📋 Security Checklist

### For Contributors

- [ ] Code follows secure coding practices
- [ ] Input validation implemented
- [ ] Output encoding applied
- [ ] Authentication and authorization properly implemented
- [ ] Sensitive data properly protected
- [ ] Dependencies are up to date
- [ ] Security tests included
- [ ] No hardcoded secrets in code

### For Maintainers

- [ ] Security review completed
- [ ] Vulnerability scan passed
- [ ] Dependencies audited
- [ ] Security tests passing
- [ ] Documentation updated
- [ ] Security advisory published (if needed)

## 🔄 Security Updates

We regularly publish security updates:

- **Security Advisories** - Published for all security fixes
- **Release Notes** - Include security-related changes
- **Security Bulletins** - Monthly security updates
- **Newsletter** - Security tips and updates

## 📞 Contact

- **Security Team**: security@normaldance.com
- **General Inquiries**: info@normaldance.com
- **Emergency**: security-emergency@normaldance.com

---

**Last Updated**: December 2024  
**Next Review**: March 2025

Thank you for helping keep NORMALDANCE secure! 🛡️
