# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated building, testing, and releasing of the furl application.

## Workflows

### 1. Build Multi-Platform Releases (`build-release.yml`)

**Trigger:** Git tags starting with `v*`, pull requests to main, manual dispatch

**Purpose:** Builds furl binaries for multiple platforms and architectures:

#### Supported Platforms & Architectures:
- **Linux:** 
  - x64 (native compilation)
  - ARM64 (cross-compiled via Docker BuildX + QEMU)
  - ARM v7 (cross-compiled via Docker BuildX + QEMU)  
  - RISC-V 64 (cross-compiled via Docker BuildX + QEMU)
- **macOS:** 
  - x64 (Intel, native compilation)
  - ARM64 (Apple Silicon, native compilation)
- **Windows:** 
  - x64 (native compilation)

#### Cross-Compilation Strategy:
- **Native builds**: Use dedicated GitHub runners for supported architectures
- **Cross-compilation**: Docker BuildX with QEMU emulation for unsupported architectures
- **Approach**: Follows the atsign-foundation/noports repository pattern for multi-architecture support

#### Outputs:
- Individual platform binaries (digitally signed)
- Compressed archives (`.tar.gz` for Unix, `.zip` for Windows)
- SHA256 checksums for all binaries
- GPG signatures for Linux binaries
- Docker images (multi-arch)
- GitHub releases for tagged versions

#### Code Signing:
- **Windows**: Authenticode signing with trusted certificate
- **macOS**: Apple code signing and notarization
- **Linux**: GPG detached signatures
- **Verification**: SHA256 checksums for all platforms

#### Release Assets:
Each release includes:
- `furl` / `furl.exe` - Main CLI application
- `furl-server` / `furl-server.exe` - Local web server
- `web/` - Browser decryption interface
- `wasm-crypto/` - WebAssembly crypto modules

### 2. Continuous Integration (`ci.yml`)

**Trigger:** Pushes to main/autobuild branches, pull requests to main

**Purpose:** Fast feedback on code changes

#### Jobs:
- **Test:** Runs on Ubuntu, macOS, Windows
  - Code analysis with `dart analyze`
  - Unit tests with `dart test --exclude-tags=performance --exclude-tags=e2e`
  - Build verification
  - Basic executable testing
  - Optional performance tests (manual workflow trigger only)

- **Lint:** Code quality checks
  - Format verification with `dart format`
  - Less Strict analysis with `--fatal-warnings `
  - Dependency validation

#### Test Exclusions:
- **Performance tests** are excluded from CI to prevent flaky failures
- **E2E tests** are excluded from CI due to network dependencies
- Use `run-all-tests.sh` (Unix) or `run-all-tests.bat` (Windows) for complete local testing

### 3. WASM Build (`wasm.yml`)

**Trigger:** Changes to `wasm-crypto/` or `web/` directories

**Purpose:** Build and test WebAssembly components

#### Features:
- Rust/WASM compilation with `wasm-pack`
- Node.js web component testing
- WASM artifact uploads

### 4. Flutter Multi-Platform Builds

**Purpose:** Build Flutter mobile and desktop applications for multiple platforms

#### Individual Platform Workflows:

**Android (`flutter-android.yml`):**
- **Trigger:** Changes to `flutter_furl/` directory, pushes to main/autobuild, PRs
- **Outputs:** APK (debug/release), AAB (Android App Bundle)
- **Features:** 
  - Java 17 setup
  - Automated namespace fixes via `fix_namespaces.sh`
  - Flutter analysis and testing
  - Artifact uploads with 30-day retention

**iOS (`flutter-ios.yml`):**
- **Trigger:** Changes to `flutter_furl/` directory, pushes to main/autobuild, PRs
- **Outputs:** iOS app bundles (unsigned)
- **Features:**
  - Simulator and device builds
  - No code signing (for CI testing)
  - Note: Requires manual code signing setup for distribution

**macOS (`flutter-macos.yml`):**
- **Trigger:** Changes to `flutter_furl/` directory, pushes to main/autobuild, PRs
- **Outputs:** macOS .app bundle, DMG installer
- **Features:**
  - Debug and release builds
  - DMG creation with fallback to ZIP
  - Desktop support enablement

**Windows (`flutter-windows.yml`):**
- **Trigger:** Changes to `flutter_furl/` directory, pushes to main/autobuild, PRs
- **Outputs:** Windows executable and dependencies
- **Features:**
  - Debug and release builds
  - ZIP archive creation
  - Desktop support enablement

#### Multi-Platform Release Workflow (`flutter-multi-platform.yml`):

**Trigger:** Git tags starting with `flutter-v*`, manual dispatch with platform selection

**Purpose:** Coordinated builds across all Flutter platforms for releases

**Features:**
- **Selective builds:** Choose which platforms to build via workflow inputs
- **Release automation:** Automatically creates GitHub releases for tagged versions
- **Artifact management:** Extended 90-day retention for release builds
- **Release notes:** Auto-generated with installation instructions

**Release Process:**
1. Tag with `flutter-v*` pattern (e.g., `flutter-v1.0.0`)
2. Push tag to trigger multi-platform build
3. Artifacts are automatically attached to GitHub release
4. Installation instructions included in release notes

**Manual Trigger Options:**
- `build_android`: Build Android APK/AAB (default: true)
- `build_macos`: Build macOS app (default: true)  
- `build_windows`: Build Windows app (default: true)

### 5. Docker Support

Multi-stage Docker builds for containerized deployment:

```bash
# Build local image
docker build -t furl .

# Run furl server
docker run -p 8080:8080 -v /path/to/files:/shared furl

# Run CLI (interactive)
docker run -it -v /path/to/files:/shared furl ./furl --help
```

## Usage Examples

### Manual Release

**CLI Tools Release:**
1. Create and push a git tag:
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
2. GitHub Actions automatically builds and creates a release

**Flutter App Release:**
1. Create and push a Flutter-specific tag:
   ```bash
   git tag flutter-v1.0.0
   git push origin flutter-v1.0.0
   ```
2. Multi-platform Flutter build automatically triggers and creates release

### Development Testing
- Push to any branch triggers CI validation
- Pull requests get full platform testing
- WASM changes trigger specialized builds
- Flutter changes trigger platform-specific builds

### Manual Flutter Builds
Trigger individual platform builds manually:
```bash
# Via GitHub CLI
gh workflow run flutter-android.yml
gh workflow run flutter-macos.yml  
gh workflow run flutter-windows.yml
gh workflow run flutter-ios.yml

# Or use the multi-platform workflow with custom options
gh workflow run flutter-multi-platform.yml \
  --field build_android=true \
  --field build_macos=false \
  --field build_windows=true
```

### Docker Deployment
- Released images available at `ghcr.io/cconstab/furl`
- Multi-architecture support (AMD64, ARM64)
- Automated builds on releases

## Environment Requirements

### Secrets
- `GITHUB_TOKEN` - Automatically provided for releases

#### Code Signing Secrets (Optional - for signed releases):

**Windows:**
- `WINDOWS_CERTIFICATE` - Base64 encoded code signing certificate
- `WINDOWS_CERTIFICATE_PASSWORD` - Certificate password

**macOS:**
- `MACOS_CERTIFICATE` - Base64 encoded Apple Developer certificate
- `MACOS_CERTIFICATE_PASSWORD` - Certificate password
- `MACOS_SIGNING_IDENTITY` - Signing identity string
- `APPLE_ID` - Apple ID for notarization
- `APPLE_APP_PASSWORD` - App-specific password
- `APPLE_TEAM_ID` - Apple Developer Team ID

**Linux:**
- `GPG_PRIVATE_KEY` - GPG private key in ASCII armor format
- `GPG_PASSPHRASE` - GPG key passphrase

📋 **See `CODE_SIGNING.md` for detailed setup instructions**

### Dependencies
- Dart SDK (stable channel)
- Rust toolchain (for WASM)
- Node.js 18+ (for web testing)

## Platform-Specific Notes

### Architecture Limitations
- Linux and Windows ARM64/RISC-V builds are not supported due to Dart's `dart compile exe` not supporting cross-compilation
- Use x64 builds with emulation if needed on ARM systems

### macOS Universal
- Separate x64 and ARM64 builds
- Use ARM64 for Apple Silicon Macs (M1/M2/M3)

### Flutter Platform Requirements

**Android:**
- Requires Java 17 for Android Gradle Plugin compatibility
- Automatic namespace fixes applied via `fix_namespaces.sh`
- Outputs both APK (sideloading) and AAB (Play Store) formats

**iOS:**
- Builds are unsigned for CI testing only
- Physical device installation requires proper code signing setup
- App Store distribution requires Apple Developer Program membership

**macOS:**
- Desktop support automatically enabled
- DMG creation requires `create-dmg` (installed via Homebrew)
- App may require user approval in Security & Privacy settings
- **Code signing and notarization**: Automatically applied when secrets are available
  - Uses same certificates as CLI tools (`MACOS_CERTIFICATE`, `MACOS_SIGNING_IDENTITY`, etc.)
  - App bundles are deep-signed with runtime hardening
  - Notarization ensures apps run without Gatekeeper warnings
  - Signed apps are suitable for distribution outside the Mac App Store

**Windows:**  
- Desktop support automatically enabled
- Outputs include all required dependencies
- No additional runtime requirements for end users

## Troubleshooting

### Build Failures
1. Check Dart SDK compatibility in `pubspec.yaml`
2. Verify all dependencies support target architecture
3. Review platform-specific compilation flags

### Release Issues
1. Ensure tag follows `v*` pattern (e.g., `v1.0.0`)
2. Check repository permissions for GitHub Packages
3. Verify all required files are included in build

### Docker Problems
1. Verify Dockerfile syntax with local build
2. Check base image compatibility
3. Ensure all runtime dependencies are included
