# Furl - Secure File Sharing

A secure file sharing system that uses multi-layer encryption and client-side decryption to protect files.

## 🚀 Quick Start

### For Compiled Binary Users

```bash
# 1. Start the server
furl_server

# 2. Share a file
furl @youratsign document.pdf 1h

# 2a. Or share with a custom message
furl @youratsign document.pdf 1h -m "Here's the report you requested"

# 3. Share the generated URL and PIN with recipient
# Recipient enters PIN in web interface to decrypt and download
```

### For Dart Developers

```bash
# 1. Install dependencies
dart pub get

# 2. Start the unified server
dart run bin/furl_server.dart

# 3. Share a file
dart run bin/furl.dart @youratsign document.pdf 1h

# 3a. Or share with a custom message
dart run bin/furl.dart @youratsign document.pdf 1h -m "Here's the report you requested"

# 4. Share the generated URL and PIN with recipient
# Recipient enters PIN in web interface to decrypt and download
```

## Features

- **Zero-Knowledge Security**: Files are encrypted before upload, decrypted in recipient's browser
- **PIN Protection**: 9-character strong PIN with special characters protects encryption keys
- **Custom Messages**: Optional custom messages for recipients (max 140 characters)
- **Public Storage**: Uses public services (filebin.net) for encrypted file storage
- **atPlatform Integration**: Metadata stored securely on atPlatform
- **Client-Side Decryption**: All decryption happens in the browser for maximum privacy

## Quick Start

### 1. Start the Server

#### Using Compiled Binary
```bash
# Start the unified server (default port 8080)
furl_server

# Or specify a custom port
furl_server --port 8090

# Or use command line options
furl_server --port 3000 --web-root public
```

#### Using Dart
```bash
# Start the unified server (default port 8080)
dart run bin/furl_server.dart

# Or specify a custom port
dart run bin/furl_server.dart 8090

# Or use command line options
dart run bin/furl_server.dart --port 3000 --web-root public
```

### 2. Upload a File

#### Using Compiled Binary
```bash
furl @youratSign path/to/file.txt 1h
```

#### Using Dart
```bash
dart run bin/furl.dart @youratSign path/to/file.txt 1h
```

This will:
- Encrypt the file with ChaCha20
- Generate a 9-character strong PIN with special characters
- Upload encrypted file to filebin.net
- Store encrypted metadata on atPlatform
- Display a URL and PIN for the recipient

### 3. Share with Recipient

Send the recipient:
1. **URL**: `http://localhost:8080/furl.html?atSign=@youratSign&key=_furl_xxxxx`
2. **PIN**: The 9-character code displayed during upload

### 4. Download and Decrypt

The recipient:
1. Opens the URL in their browser
2. Enters the PIN
3. Clicks "Download & Decrypt"
4. Gets the original file automatically decrypted

## How It Works

### Upload Process
```
Original File → ChaCha20 Encrypt → Upload to filebin.net
                     ↓
            ChaCha20 Key → PIN Encrypt → Store on atPlatform
```

### Download Process
```
atPlatform → Get Encrypted Metadata → PIN Decrypt → ChaCha20 Key
filebin.net → Get Encrypted File → ChaCha20 Decrypt → Original File
```

### Security Model

1. **File Encryption**: Each file is encrypted with a unique 256-bit ChaCha20 key
2. **Key Protection**: The ChaCha20 key is encrypted using a PIN-derived key  
3. **Separation**: File data and encryption keys are stored separately
4. **Client-Side**: All decryption happens in the recipient's browser
5. **Zero-Knowledge**: Servers never see plaintext files or PINs

## Prerequisites

- Dart SDK
- Activated atSign (use `dart run at_activate --atsign @youratSign`)
- Network connectivity for atPlatform and filebin.net
- **Rust and wasm-pack** (required for browser decryption)

### Initial Setup

Before using the web interface, you must build the WASM module:

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install wasm-pack
cargo install wasm-pack

# Build the WASM crypto module
cd wasm-crypto

# On Linux/macOS:
./build.sh

# On Windows:
build.bat

# Or manually with wasm-pack:
# wasm-pack build --target web --out-dir ../web/wasm

cd ..

# Now you can use both CLI and web interface
```

## Command Line Usage

```bash
# Using compiled binary
furl @alice document.pdf 1h

# With verbose output  
furl @alice document.pdf 1h -v

# With quiet mode (no progress bars)
furl @alice document.pdf 1h -q

# With a custom message for the recipient
furl @alice document.pdf 1h -m "Here is the contract"

# Using Dart (for development)
dart run bin/furl.dart @alice document.pdf 1h

# With verbose output
dart run bin/furl.dart @alice document.pdf 1h -v

# Parameters:
# @alice       - Your atSign
# document.pdf - File to encrypt and share
# 1h           - TTL (1 hour, can use: 30s, 10m, 2h, 7d, or seconds)
# -v           - Verbose output (optional)
# -q           - Quiet mode - no progress bars (optional)
# -m "message" - Custom message for recipient (max 140 chars, optional)
```

## Server Configuration

### Unified Server (bin/furl_server.dart)
- **Default Port**: 8080
- **Command Line Options**:
  - `--port <port>` - Specify server port
  - `--web-root <path>` - Specify web files directory (default: web)
  - `--help` - Show help message
- **API Endpoints** (prefixed with `/api/`):
  - `GET /api/atsign/{atSign}` - Resolve atSign to atServer
  - `GET /api/fetch/{atSign}/{keyName}` - Fetch encrypted metadata
  - `GET /api/download?url={url}` - Proxy file downloads
  - `GET /api/health` - Health check
- **Web Interface**:
  - `GET /` - Redirects to furl.html
  - `GET /furl.html` - File decryption interface
  - Static files served from web/ directory

## WebAssembly (WASM) High-Performance Decryption

**REQUIRED**: Furl now uses pure WebAssembly (WASM) for all browser-based decryption to ensure optimal performance and consistent behavior. The web interface requires WASM support and will not fall back to JavaScript crypto APIs.

### WASM Prerequisites

To build and use the WASM module (required for browser decryption):

1. **Rust**: Install from [rustup.rs](https://rustup.rs/)
2. **wasm-pack**: Install with `cargo install wasm-pack`
3. **Modern Browser**: Chrome, Firefox, Safari, or Edge with WebAssembly support

### Building the WASM Module

```bash
# Navigate to the WASM crypto directory
cd wasm-crypto

# On Linux/macOS - use the build script:
./build.sh

# On Windows - use the batch script:
build.bat

# Or manually with wasm-pack:
wasm-pack build --target web --out-dir ../web/wasm

# The generated files will be in web/wasm/
```

### WASM Build Troubleshooting

**Permission denied on macOS/Linux:**
```bash
chmod +x build.sh
./build.sh
```

**Missing Rust/wasm-pack:**
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Install wasm-pack
cargo install wasm-pack
```

**Build fails with target error:**
```bash
# Add the wasm32 target
rustup target add wasm32-unknown-unknown
```

**Module not found in browser:**
Check that files were generated in `web/wasm/` directory:
- `wasm_crypto.js`
- `wasm_crypto_bg.wasm`
- `package.json`

### WASM Integration

The web interface requires the WASM module for decryption:

1. **Pure WASM**: No JavaScript crypto fallbacks - ensures consistent performance
2. **Memory Efficient**: Streaming decryption with chunked processing
3. **File System API**: Large files can be streamed directly to disk (Chrome/Edge)
4. **Progress Tracking**: Real-time progress updates during download and decryption

### Performance Benefits

- **All file sizes**: Consistent WASM-accelerated ChaCha20 decryption
- **Memory efficient**: Constant memory usage regardless of file size
- **Streaming**: Download and decrypt simultaneously for large files
- **Direct to disk**: Files >10MB can bypass browser memory entirely

### Development Notes

The WASM module source is in `wasm-crypto/src/lib.rs` and uses:
- `chacha20` crate for ChaCha20 encryption primitives
- `wasm-bindgen` for JavaScript integration
- `js-sys` for browser API access

**Important**: WASM module must be built before browser decryption will work. Build artifacts are excluded from the repository.

## Security Features

### Defense in Depth
- **Layer 1**: ChaCha20 file encryption
- **Layer 2**: PIN-protected key encryption  
- **Layer 3**: Separate storage of files and metadata
- **Layer 4**: Client-side decryption only

### Privacy Protection
- Servers never see plaintext files
- PINs never leave the recipient's browser
- Zero-knowledge architecture
- Forward secrecy (unique keys per file)

### Access Control
- Requires both URL and PIN
- Time-limited access (TTL)
- Single-use URLs (can be configured)

## The Role of the PIN

The **PIN serves as a shared secret** that enables secure key exchange:

1. **Key Protection**: Protects the ChaCha20 encryption key with an additional layer
2. **Zero-Knowledge**: PIN never leaves the recipient's browser  
3. **Access Control**: Requires both URL and PIN for file access
4. **Forward Secrecy**: Each file gets a unique PIN and ChaCha20 key

### PIN Security Process

**Upload (Sender)**:
```
1. Generate random 9-char PIN
2. Derive key: PIN_Key = SHA256(PIN_bytes + Salt_bytes)  
3. Encrypt: Encrypted_ChaCha20_Key = ChaCha20(ChaCha20_Key, PIN_Key)
4. Store encrypted ChaCha20 key + salt in atPlatform
5. Share URL + PIN with recipient
```

**Download (Recipient)**:
```
1. Enter PIN in browser
2. Derive same key: PIN_Key = SHA256(PIN_bytes + Salt_bytes)
3. Decrypt: ChaCha20_Key = ChaCha20-DECRYPT(Encrypted_ChaCha20_Key, PIN_Key)  
4. Use ChaCha20_Key to decrypt the downloaded file
```

## File Structure

```
bin/
  furl.dart          # Main CLI tool for encryption/upload
  furl_server.dart   # Unified server (API + Web)
web/
  furl.html          # Client-side decryption interface
  wasm-crypto.js     # WASM crypto module loader
  wasm/              # WebAssembly crypto module (built from wasm-crypto/)
wasm-crypto/         # WASM source code (Rust)
  src/lib.rs         # ChaCha20 WASM implementation
test/
  furl_test.dart     # Tests
SECURITY_DESIGN.md   # Detailed security analysis
```

## Troubleshooting

### Common Issues

1. **"Failed to authenticate"**: Make sure your atSign is activated
2. **"Could not fetch data"**: Ensure API server is running on correct port
3. **"Failed to download file"**: Check network connectivity to filebin.net
4. **"Invalid PIN"**: Ensure you're entering the exact 9-character PIN
5. **"WASM module not available"**: Build the WASM module with `wasm-pack` first

### Debug Mode

Run with `-v` flag for verbose output:
```bash
# Using compiled binary
furl @alice file.txt 1h -v

# Using Dart
dart run bin/furl.dart @alice file.txt 1h -v
```

### Check Server Status

```bash
# Test unified server health
curl http://localhost:8080/api/health

# Test web interface
curl http://localhost:8080/furl.html
```

## Security Considerations

- **PIN Strength**: 9 characters provide ~60 bits of entropy
- **Key Derivation**: Uses SHA-256 (could be enhanced with PBKDF2)
- **Transport**: Uses HTTPS for all external communications
- **Storage**: No sensitive data stored on servers

For detailed security analysis, see [SECURITY_DESIGN.md](SECURITY_DESIGN.md).

## Development

### Running Tests

#### Quick Testing (CI-compatible tests only)
```bash
dart test
```

#### Comprehensive Testing (includes performance and E2E tests)
```bash
# On Unix/Linux/macOS
./run-all-tests.sh

# On Windows
run-all-tests.bat
```

#### Individual Test Suites
```bash
# Core functionality tests (crypto and CLI validation only)
dart test test/crypto_test.dart test/cli_validation_test.dart test/furl_test.dart

# Server integration tests (requires process spawning)
dart test test/server_test.dart

# Performance tests (local development only)
dart test test/performance_test.dart

# End-to-end tests (requires network)
dart test test/e2e_test.dart
```

**Note:** Performance and E2E tests are excluded from CI builds to prevent flaky failures. Use the comprehensive test runners for complete local validation.

### Project Structure

```
furl/
├── bin/                    # Executable scripts
│   ├── furl.dart          # Main CLI tool for encryption/upload
│   └── furl_server.dart   # Unified server (API + Web)
├── web/                   # Web interface
│   ├── furl.html          # Client-side decryption interface
│   ├── wasm-crypto.js     # WASM crypto module loader
│   └── wasm/              # WebAssembly crypto module (generated)
├── wasm-crypto/           # WASM source code
│   ├── src/lib.rs         # Rust ChaCha20 implementation
│   └── Cargo.toml         # Rust dependencies
├── test/                  # Test suite
│   └── furl_test.dart     # Security and integration tests
├── README.md              # This file
├── SECURITY_DESIGN.md     # Detailed security analysis
├── CHANGELOG.md           # Version history
└── LICENSE                # GPL v3 license
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `dart test`
6. Submit a pull request

## License

This project is provided as-is for educational and research purposes.
