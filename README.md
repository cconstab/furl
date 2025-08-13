# Furl - Secure File Sharing

A secure file sharing system that uses multi-layer encryption and client-side decryption to protect files.

## Features

- **Zero-Knowledge Security**: Files are encrypted before upload, decrypted in recipient's browser
- **PIN Protection**: 9-character PIN protects encryption keys
- **Public Storage**: Uses public services (filebin.net) for encrypted file storage
- **atPlatform Integration**: Metadata stored securely on atPlatform
- **Client-Side Decryption**: All decryption happens in the browser for maximum privacy

## Quick Start

### 1. Start the Servers

```bash
# Terminal 1: Start API server
dart run bin/furl_api.dart 8085

# Terminal 2: Start web server  
dart run bin/furl_web.dart
```

### 2. Upload a File

```bash
dart run bin/furl.dart @youratSign path/to/file.txt 3600
```

This will:
- Encrypt the file with AES-256
- Generate a 9-character PIN
- Upload encrypted file to filebin.net
- Store encrypted metadata on atPlatform
- Display a URL and PIN for the recipient

### 3. Share with Recipient

Send the recipient:
1. **URL**: `http://localhost:8081/furl.html?atSign=@youratSign&key=_furl_xxxxx`
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
Original File → AES-256 Encrypt → Upload to filebin.net
                     ↓
            AES Key → PIN Encrypt → Store on atPlatform
```

### Download Process
```
atPlatform → Get Encrypted Metadata → PIN Decrypt → AES Key
filebin.net → Get Encrypted File → AES Decrypt → Original File
```

### Security Model

1. **File Encryption**: Each file is encrypted with a unique 256-bit AES key
2. **Key Protection**: The AES key is encrypted using a PIN-derived key  
3. **Separation**: File data and encryption keys are stored separately
4. **Client-Side**: All decryption happens in the recipient's browser
5. **Zero-Knowledge**: Servers never see plaintext files or PINs

## Prerequisites

- Dart SDK
- Activated atSign (use `dart run at_activate --atsign @youratSign`)
- Network connectivity for atPlatform and filebin.net

## Command Line Usage

```bash
# Basic usage
dart run bin/furl.dart @alice document.pdf 3600

# With verbose output
dart run bin/furl.dart @alice document.pdf 3600 -v

# Parameters:
# @alice    - Your atSign
# document.pdf - File to encrypt and share
# 3600      - TTL in seconds (1 hour)
# -v        - Verbose output (optional)
```

## Server Configuration

### API Server (bin/furl_api.dart)
- **Default Port**: 8080 (or specify: `dart run bin/furl_api.dart 8085`)
- **Endpoints**:
  - `GET /atsign/{atSign}` - Resolve atSign to atServer
  - `GET /fetch/{atSign}/{keyName}` - Fetch encrypted metadata
  - `GET /download?url={url}` - Proxy file downloads
  - `GET /health` - Health check

### Web Server (bin/furl_web.dart)  
- **Default Port**: 8081
- **Purpose**: Serves the HTML interface for decryption
- **Files**: Serves from `web/` directory

## Security Features

### Defense in Depth
- **Layer 1**: AES-256 file encryption
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

1. **Key Protection**: Protects the AES encryption key with an additional layer
2. **Zero-Knowledge**: PIN never leaves the recipient's browser  
3. **Access Control**: Requires both URL and PIN for file access
4. **Forward Secrecy**: Each file gets a unique PIN and AES key

### PIN Security Process

**Upload (Sender)**:
```
1. Generate random 9-char PIN
2. Derive key: PIN_Key = SHA256(PIN_bytes + Salt_bytes)  
3. Encrypt: Encrypted_AES_Key = AES-256(AES_Key, PIN_Key)
4. Store encrypted AES key + salt in atPlatform
5. Share URL + PIN with recipient
```

**Download (Recipient)**:
```
1. Enter PIN in browser
2. Derive same key: PIN_Key = SHA256(PIN_bytes + Salt_bytes)
3. Decrypt: AES_Key = AES-256-DECRYPT(Encrypted_AES_Key, PIN_Key)  
4. Use AES_Key to decrypt the downloaded file
```

## File Structure

```
bin/
  furl.dart          # Main CLI tool for encryption/upload
  furl_api.dart      # API server for atSign resolution and data proxy
  furl_web.dart      # Static web server
web/
  furl.html          # Client-side decryption interface  
lib/
  furl.dart          # Core library (if needed)
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

### Debug Mode

Run with `-v` flag for verbose output:
```bash
dart run bin/furl.dart @alice file.txt 3600 -v
```

### Check Server Status

```bash
# Test API server
curl http://localhost:8085/health

# Test web server  
curl http://localhost:8081/furl.html
```

## Security Considerations

- **PIN Strength**: 9 characters provide ~60 bits of entropy
- **Key Derivation**: Uses SHA-256 (could be enhanced with PBKDF2)
- **Transport**: Uses HTTPS for all external communications
- **Storage**: No sensitive data stored on servers

For detailed security analysis, see [SECURITY_DESIGN.md](SECURITY_DESIGN.md).

## License

This project is provided as-is for educational and research purposes.

```bash
dart run bin/furl.dart <file_path> <ttl_seconds>
```

Example:
```bash
dart run bin/furl.dart document.pdf 3600
```

This will:
- Generate a 9-character PIN (share this with recipient)
- Encrypt and upload the file
- Store secrets in atPlatform for 1 hour (3600 seconds)
- Print a URL for the recipient

### Receiving a File

1. Open the URL provided by sender in a web browser
2. Enter the 9-character PIN when prompted
3. Click "Download & Decrypt File"
4. The original file will be downloaded automatically

## Security Features

- **End-to-end encryption**: Files are encrypted before upload
- **Ephemeral keys**: AES keys are generated fresh for each file
- **PIN protection**: AES keys are encrypted with recipient's PIN
- **Automatic expiration**: Secrets expire after configured TTL
- **No persistent storage**: atPlatform only stores encrypted metadata

## Configuration

### atSign Setup

1. Update `bin/furl.dart` to use your atSign instead of `@cconstab`
2. Ensure your atSign keys are available at `~/.atsign/keys/`
3. Set `useMockAtClient = false` for production use

### File Hosting

The current implementation includes example code for uploading to file hosting services. You can:

1. Use transfer.sh (uncomment the relevant code)
2. Use filebin.net (requires API adjustments)
3. Implement your own file hosting solution

## Development

### Testing

The application includes a test mode that simulates file upload and atPlatform storage locally:

```bash
dart run bin/furl.dart test_file.txt 600
```

Test the web interface:
```bash
cd web
python -m http.server 8000
# Open http://localhost:8000/?atSign=@cconstab&key=furl_1234567890
```

### Project Structure

```
furl/
├── bin/
│   └── furl.dart           # CLI application
├── web/
│   └── index.html          # Web decryption interface
├── lib/
│   └── furl.dart           # Library code
├── test/
│   └── furl_test.dart      # Tests
└── pubspec.yaml            # Dependencies
```

## Dependencies

- `at_client`: atPlatform client library
- `encrypt`: AES encryption
- `crypto`: Cryptographic functions
- `http`: HTTP client for file uploads
- `random_string`: PIN generation

## Security Considerations

- PINs are 9 characters (alphanumeric) providing ~10^13 combinations
- AES-256 provides strong file encryption
- atPlatform provides secure, decentralized secret storage
- TTL ensures secrets don't persist indefinitely
- No file content is stored in atPlatform (only metadata)

## License

This project is a demonstration of atPlatform capabilities for secure file transfer.
