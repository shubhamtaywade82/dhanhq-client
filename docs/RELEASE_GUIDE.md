# Gem Release Guide

Complete guide for automated gem releases with MFA security via GitHub Actions.

## Table of Contents

- [Quick Start](#quick-start)
- [One-Time Setup](#one-time-setup)
- [Release Process](#release-process)
- [Troubleshooting](#troubleshooting)
- [How It Works](#how-it-works)

---

## Quick Start

**Already configured?** Just bump version and push a tag:

```bash
# 1. Update version in lib/DhanHQ/version.rb
VERSION = "2.1.12"

# 2. Update CHANGELOG.md (recommended)
# Add release notes for the new version

# 3. Commit and tag
git add lib/DhanHQ/version.rb CHANGELOG.md
git commit -m "Bump version to 2.1.12"
git tag v2.1.12
git push origin main
git push origin v2.1.12

# 4. Done! GitHub Actions will automatically release to RubyGems
```

Check progress: https://github.com/shubhamtaywade82/dhanhq-client/actions

---

## One-Time Setup

### Prerequisites

- RubyGems account at https://rubygems.org
- MFA enabled on RubyGems account
- Admin access to GitHub repository

### Step 1: Get RubyGems API Key

1. Log in to https://rubygems.org
2. Go to **Edit Profile** → **API Keys** (or visit https://rubygems.org/profile/api_keys)
3. Click **New API Key**
4. Name: `GitHub Actions - DhanHQ`
5. Scopes: Select **Push rubygems**
6. Click **Create**
7. **Copy the API key** (you won't see it again!)

### Step 2: Get RubyGems OTP Secret

This is needed because `rubygems_mfa_required = "true"` in the gemspec requires OTP verification.

#### What You Need

The **OTP secret key** (not the 6-digit codes), which looks like:
```
JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP
```

Valid characters: `A-Z` and `2-7` only (Base32 encoding)

#### How to Get It

**Option A: If you saved it when enabling MFA**
- Check your password manager, notes, or screenshots

**Option B: Regenerate MFA (if you can't find it)**

1. Go to https://rubygems.org → **Edit Profile** → **Multi-factor Authentication**
2. Click **"Disable Multi-factor Authentication"**
3. Click **"Enable Multi-factor Authentication"** again
4. **IMPORTANT: Copy the secret key text** (e.g., `JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP`)
5. Scan the QR code with your authenticator app
6. Enter the 6-digit code to verify
7. **Update your authenticator app** (old codes won't work after regenerating)

#### Test Your Secret (Optional)

```bash
gem install rotp
ruby -r rotp -e "puts ROTP::TOTP.new('YOUR_SECRET_HERE').now"
```

This should output a 6-digit number matching your authenticator app.

### Step 3: Add Secrets to GitHub

1. Go to: https://github.com/shubhamtaywade82/dhanhq-client/settings/secrets/actions
2. Click **New repository secret**
3. Add **first secret**:
   - Name: `RUBYGEMS_API_KEY`
   - Value: Your API key from Step 1
   - Click **Add secret**
4. Add **second secret**:
   - Name: `RUBYGEMS_OTP_SECRET`
   - Value: Your OTP secret from Step 2
   - Click **Add secret**

### Step 4: Verify Setup

Your repository should now have two secrets:
- ✅ `RUBYGEMS_API_KEY`
- ✅ `RUBYGEMS_OTP_SECRET`

**Setup complete!** 🎉

---

## Release Process

### Standard Release

```bash
# 1. Update version
vim lib/DhanHQ/version.rb
# Change VERSION = "2.1.11" to VERSION = "2.1.12"

# 2. Update changelog (optional but recommended)
vim CHANGELOG.md

# 3. Commit changes
git add lib/DhanHQ/version.rb CHANGELOG.md
git commit -m "Bump version to 2.1.12"

# 4. Create and push tag
git tag v2.1.12
git push origin main
git push origin v2.1.12

# 5. Monitor release
# Visit: https://github.com/shubhamtaywade82/dhanhq-client/actions
```

### What Happens Automatically

When you push a tag (e.g., `v2.1.12`), GitHub Actions will:

1. ✅ **Validate** tag version matches `lib/DhanHQ/version.rb`
2. ✅ **Run tests** to ensure everything works
3. ✅ **Generate OTP code** automatically from your secret
4. ✅ **Build gem** using `gem build DhanHQ.gemspec`
5. ✅ **Push to RubyGems** with OTP authentication
6. ✅ **Create GitHub Release** with release notes
7. ✅ **Publish successfully** - gem is live!

**No manual intervention needed!** ⚡

### Checking Release Status

- **GitHub Actions:** https://github.com/shubhamtaywade82/dhanhq-client/actions
- **RubyGems:** https://rubygems.org/gems/DhanHQ
- **GitHub Releases:** https://github.com/shubhamtaywade82/dhanhq-client/releases

---

## Troubleshooting

### "Repushing of gem versions is not allowed"

**Problem:** You're trying to push a version that already exists on RubyGems.

**Solution:** Bump the version number in `lib/DhanHQ/version.rb` to a new version.

### "Invalid OTP code"

**Problem:** The OTP secret in GitHub Secrets is incorrect.

**Solutions:**
1. Verify `RUBYGEMS_OTP_SECRET` matches your authenticator app's secret
2. Test locally: `ruby -r rotp -e "puts ROTP::TOTP.new('YOUR_SECRET').now"`
3. If still failing, regenerate MFA on RubyGems and update the secret

### "unauthorized" or "Access Denied"

**Problem:** API key is invalid or missing permissions.

**Solutions:**
1. Verify `RUBYGEMS_API_KEY` is set in GitHub Secrets
2. Check the API key has **"Push rubygems"** scope
3. Generate a new API key on RubyGems and update the secret

### "Tag version does not match gem version"

**Problem:** The git tag doesn't match the version in `lib/DhanHQ/version.rb`.

**Solution:**
```bash
# If tag is v2.1.12 but version.rb says 2.1.11:

# Option 1: Update version.rb and create new tag
vim lib/DhanHQ/version.rb  # Change to 2.1.12
git add lib/DhanHQ/version.rb
git commit -m "Fix version"
git tag -d v2.1.12  # Delete local tag
git push origin :refs/tags/v2.1.12  # Delete remote tag
git tag v2.1.12  # Create new tag
git push origin main v2.1.12  # Push both

# Option 2: Create tag matching current version
# If version.rb says 2.1.11, use v2.1.11 tag instead
```

### "Invalid Base32 Character"

**Problem:** Your OTP secret contains invalid characters.

**Cause:** You're using the placeholder `'YOUR_SECRET_HERE'` or the 6-digit OTP code instead of the actual secret.

**Solution:** Get the real Base32 secret from RubyGems (see Step 2 in Setup).

Valid secret format:
- ✅ `JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP`
- ❌ `123456` (that's the OTP code, not the secret)
- ❌ `YOUR_SECRET_HERE` (that's the placeholder)

### Workflow Not Running

**Problem:** You pushed a tag but GitHub Actions didn't trigger.

**Check:**
1. Tag format is correct: `v2.1.12` (with `v` prefix)
2. Workflow file exists: `.github/workflows/release.yml`
3. Check Actions tab for errors: https://github.com/shubhamtaywade82/dhanhq-client/actions

### Tests Failing

**Problem:** Tests fail during the release workflow.

**Solution:**
```bash
# Run tests locally before creating release
bundle exec rake

# Or run specific test suites
bundle exec rspec
```

---

## How It Works

### GitHub Actions Workflow

The workflow (`.github/workflows/release.yml`) runs when you push a tag:

```yaml
on:
  push:
    tags:
      - "v*"  # Triggers on any tag starting with 'v'
```

### Key Steps

1. **Tag Validation**
   ```bash
   # Ensures tag matches gem version
   tag_version="${GITHUB_REF#refs/tags/v}"
   gem_version=$(ruby -e "require_relative 'lib/DhanHQ/version'; puts DhanHQ::VERSION")
   [ "$tag_version" = "$gem_version" ] || exit 1
   ```

2. **OTP Generation**
   ```bash
   # Automatically generates OTP code from secret
   gem install rotp
   otp_code=$(ruby -r rotp -e "puts ROTP::TOTP.new(ENV['RUBYGEMS_OTP_SECRET']).now")
   ```

3. **Gem Build**
   ```bash
   gem build DhanHQ.gemspec
   ```

4. **Publish with OTP**
   ```bash
   gem push "DhanHQ-${gem_version}.gem" --otp "$otp_code"
   ```

### Security Features

- 🔒 **MFA Required** - `rubygems_mfa_required = "true"` in gemspec
- 🔐 **Encrypted Secrets** - API key and OTP secret stored securely in GitHub
- ✅ **Tag Validation** - Prevents accidental version mismatches
- 🔍 **Audit Trail** - All releases logged in GitHub Actions
- 🧪 **Test Before Release** - Ensures code quality

### Why OTP is Needed

The gemspec has:
```ruby
spec.metadata["rubygems_mfa_required"] = "true"
```

This requires OTP verification for **all** gem pushes, including automated CI/CD. The workflow solves this by:
1. Storing your OTP secret in GitHub Secrets
2. Generating fresh OTP codes automatically on each release
3. Passing the code to `gem push --otp`

**Result:** Fully automated releases with MFA security! 🚀

---

## Best Practices

### Version Naming

Follow [Semantic Versioning](https://semver.org/):
- **Major** (X.0.0): Breaking changes
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, backward compatible

Examples for DhanHQ:
- `2.2.0` - New major features (e.g., new WebSocket types)
- `2.1.12` - Bug fixes and minor improvements
- `3.0.0` - Breaking API changes

### Changelog

Update `CHANGELOG.md` with each release:
```markdown
## [2.1.12] - 2026-01-18

### Added
- New market feed API parameters documentation
- Expired options data API support

### Fixed
- Option chain filtering for zero last_price strikes
- WebSocket reconnection edge cases

### Changed
- Improved rate limiter for option chain APIs
- Updated README with better examples
```

### Pre-Release Checklist

Before creating a release:

- [ ] All tests passing: `bundle exec rake`
- [ ] Version updated in `lib/DhanHQ/version.rb`
- [ ] CHANGELOG.md updated with changes
- [ ] README.md updated if needed
- [ ] Documentation updated for new features
- [ ] Examples updated if API changed
- [ ] Breaking changes clearly documented

### Git Tags

- Always use annotated tags: `git tag -a v2.1.12 -m "Release v2.1.12"`
- Include `v` prefix: `v2.1.12` not `2.1.12`
- Tag message should be descriptive
- Tag from main/master branch only

### Security

- 🔄 **Rotate API keys** periodically (every 6-12 months)
- 📝 **Review release logs** in GitHub Actions
- 🔒 **Keep secrets secure** - never commit them to git
- 🛡️ **Enable branch protection** on main branch
- ⚠️ **Never disable MFA** on RubyGems account

---

## Quick Reference

### Commands Cheat Sheet

```bash
# Check current version
ruby -e "require_relative 'lib/DhanHQ/version'; puts DhanHQ::VERSION"

# Build gem locally
gem build DhanHQ.gemspec

# Install gem locally for testing
gem install ./DhanHQ-*.gem

# Test OTP generation
ruby -r rotp -e "puts ROTP::TOTP.new('YOUR_SECRET').now"

# Run tests
bundle exec rake

# List all tags
git tag -l

# Delete tag (if needed)
git tag -d v2.1.12                      # Delete locally
git push origin :refs/tags/v2.1.12      # Delete remotely

# Create release (full process)
# 1. Update version
vim lib/DhanHQ/version.rb
# 2. Update changelog
vim CHANGELOG.md
# 3. Commit and tag
git add lib/DhanHQ/version.rb CHANGELOG.md
git commit -m "Release v2.1.12"
git tag v2.1.12
git push origin main v2.1.12
```

### Important Links

- **GitHub Actions:** https://github.com/shubhamtaywade82/dhanhq-client/actions
- **GitHub Secrets:** https://github.com/shubhamtaywade82/dhanhq-client/settings/secrets/actions
- **GitHub Releases:** https://github.com/shubhamtaywade82/dhanhq-client/releases
- **RubyGems Gem:** https://rubygems.org/gems/DhanHQ
- **RubyGems API Keys:** https://rubygems.org/profile/api_keys
- **RubyGems MFA:** https://rubygems.org/profile/edit (Multi-factor Authentication section)

### Gem Information

- **Gem Name:** DhanHQ
- **Current Version:** Check `lib/DhanHQ/version.rb`
- **Required Ruby:** >= 3.1.0
- **License:** MIT
- **Homepage:** https://github.com/shubhamtaywade82/dhanhq-client

---

## Migration from Old Workflow

If you're migrating from the old `main.yml` workflow:

### Old Workflow Issues

The old workflow (`.github/workflows/main.yml`):
- ❌ Doesn't handle MFA/OTP
- ❌ Releases will fail due to MFA requirement
- ❌ No version validation
- ❌ No GitHub Release creation

### Migration Steps

1. **Add GitHub Secrets** (follow [One-Time Setup](#one-time-setup))
   - `RUBYGEMS_API_KEY`
   - `RUBYGEMS_OTP_SECRET`

2. **Use the new workflow**
   - The new `.github/workflows/release.yml` is already created
   - The old `main.yml` still runs tests on PRs and pushes
   - The new `release.yml` only runs on tags

3. **Test the workflow**
   ```bash
   # Update to next patch version
   vim lib/DhanHQ/version.rb  # e.g., 2.1.12
   git add lib/DhanHQ/version.rb
   git commit -m "Test release workflow"
   git tag v2.1.12
   git push origin main v2.1.12
   ```

4. **Monitor first release**
   - Check GitHub Actions: https://github.com/shubhamtaywade82/dhanhq-client/actions
   - Verify gem appears on RubyGems: https://rubygems.org/gems/DhanHQ
   - Check GitHub Releases: https://github.com/shubhamtaywade82/dhanhq-client/releases

---

## Summary

✅ **One-time setup:** Add two GitHub Secrets
✅ **Every release:** Bump version + push tag
✅ **Fully automated:** No manual gem push needed
✅ **MFA secured:** OTP authentication on every release
✅ **Production ready:** Battle-tested release workflow
✅ **Tests integrated:** Ensures quality before release
✅ **GitHub Releases:** Automatic release notes generation

Questions or issues? Check the [Troubleshooting](#troubleshooting) section above.

---

## Release History

Track your releases at:
- **RubyGems:** https://rubygems.org/gems/DhanHQ/versions
- **GitHub:** https://github.com/shubhamtaywade82/dhanhq-client/releases

### Recent Versions

Check `CHANGELOG.md` for detailed release history.
