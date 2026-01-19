# Quick Release Guide

This is a quick reference for releasing DhanHQ. For detailed instructions, see [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md).

## First Time? Setup Required

You need to configure GitHub Secrets once:

1. Get your RubyGems API key: https://rubygems.org/profile/api_keys
2. Get your RubyGems OTP secret (from MFA setup)
3. Add both to GitHub Secrets: https://github.com/shubhamtaywade82/dhanhq-client/settings/secrets/actions
   - `RUBYGEMS_API_KEY`
   - `RUBYGEMS_OTP_SECRET`

**See [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md#one-time-setup) for detailed setup instructions.**

## Regular Release Process

```bash
# 1. Update version
vim lib/DhanHQ/version.rb
# Change VERSION = "2.1.11" to VERSION = "2.1.12"

# 2. Update changelog (recommended)
vim CHANGELOG.md

# 3. Commit and tag
git add lib/DhanHQ/version.rb CHANGELOG.md
git commit -m "Release v2.1.12"
git tag v2.1.12

# 4. Push (this triggers automatic release)
git push origin main
git push origin v2.1.12
```

That's it! GitHub Actions will:
- ✅ Run tests
- ✅ Build gem
- ✅ Generate OTP automatically
- ✅ Publish to RubyGems
- ✅ Create GitHub Release

## Check Release Status

- **GitHub Actions:** https://github.com/shubhamtaywade82/dhanhq-client/actions
- **RubyGems:** https://rubygems.org/gems/DhanHQ
- **GitHub Releases:** https://github.com/shubhamtaywade82/dhanhq-client/releases

## Troubleshooting

See [docs/RELEASE_GUIDE.md#troubleshooting](docs/RELEASE_GUIDE.md#troubleshooting)

## Version Guidelines

- **Patch** (2.1.X): Bug fixes
- **Minor** (2.X.0): New features
- **Major** (X.0.0): Breaking changes

Follow [Semantic Versioning](https://semver.org/).
