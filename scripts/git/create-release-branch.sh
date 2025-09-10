#!/bin/bash
set -e

VERSION="v2.0.0-production-ready"
BRANCH_NAME="release/$VERSION"

echo "🚀 Creating release branch: $BRANCH_NAME"

git checkout -b $BRANCH_NAME
git add .
git commit -m "feat: Production-ready release $VERSION

✅ Security fixes implemented
✅ Infrastructure improvements  
✅ CI/CD pipeline ready
✅ Monitoring & alerting
✅ Complete documentation

Ready for production deployment!"

git push -u origin $BRANCH_NAME

echo "✅ Release branch created: $BRANCH_NAME"