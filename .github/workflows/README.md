# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated building, testing, and releasing of the furl application.

## Workflows

### 1. Build Multi-Platform Releases (`build-release.yml`)

**Trigger:** Git tags starting with `v*`, pull requests to main, manual dispatch

**Purpose:** Builds furl binaries for multiple platforms and architectures:

#### Supported Platforms & Architectures:
- **Linux:** x64, ARM64, RISC-V 64
- **macOS:** x64 (Intel), ARM64 (Apple Silicon)  
- **Windows:** x64, ARM64

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
  - Strict analysis with `--fatal-infos`
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

### 4. Docker Support

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
1. Create and push a git tag:
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
2. GitHub Actions automatically builds and creates a release

### Development Testing
- Push to any branch triggers CI validation
- Pull requests get full platform testing
- WASM changes trigger specialized builds

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

### Linux RISC-V
- Experimental support via Dart's RISC-V 64 target
- May have limited package availability

### macOS Universal
- Separate x64 and ARM64 builds
- Use ARM64 for Apple Silicon Macs (M1/M2/M3)

### Windows ARM64
- Native ARM64 support for Surface Pro X and similar devices
- Fallback to x64 emulation if needed

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
