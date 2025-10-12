# Furl Architecture

## Overview

Furl is a secure file sharing system built on the atPlatform that combines end-to-end encryption with decentralized key management. Files are encrypted client-side, uploaded to a configurable filebin server, and the decryption metadata is stored securely on the atPlatform.

## Core Components

### 1. Encryption Layer
- **Algorithm**: ChaCha20 stream cipher with 256-bit keys
- **Key Generation**: Cryptographically secure random key generation
- **PIN Protection**: 9-character strong PIN with special characters
- **Integrity**: SHA-512 hash verification

### 2. Storage Layer
- **Filebin Server**: Stores encrypted file blobs (configurable)
- **atPlatform**: Stores decryption metadata in encrypted atKeys
- **Time-To-Live**: Automatic expiration from 30 seconds to 6 days

### 3. Configuration System
- **atKey-based**: Configuration stored in encrypted atKeys (not local files)
- **Three-tier resolution**: Private override → Public config → Default fallback
- **Real-time sync**: Changes propagate immediately across all devices

## System Architecture

```mermaid
graph TB
    subgraph "Sender Side"
        A[User] --> B[furl CLI/App]
        B --> C[File Encryption<br/>ChaCha20]
        C --> D[Generate Metadata]
        D --> E[Upload Encrypted File]
        D --> F[Store Metadata]
        E --> G[Filebin Server]
        F --> H[atPlatform<br/>Secondary Server]
    end
    
    subgraph "Configuration"
        I[ConfigManager] --> J{Resolve Filebin URL}
        J --> K[Private Override<br/>private:filebin_override.furl@user]
        J --> L[Public Config<br/>public:filebin.furl@furl]
        J --> M[Default Fallback<br/>https://filebin.net]
    end
    
    subgraph "Receiver Side"
        N[Recipient] --> O[furl CLI/App]
        O --> P[Fetch Metadata]
        O --> Q[Download Encrypted File]
        P --> H
        Q --> G
        P --> R[Decrypt File<br/>ChaCha20]
        Q --> R
        R --> S[Verify Hash<br/>SHA-512]
        S --> T[Save Decrypted File]
    end
    
    B --> I
    O --> I
    
    style C fill:#e1f5ff
    style R fill:#e1f5ff
    style G fill:#fff4e1
    style H fill:#f0e1ff
    style I fill:#e1ffe1
```

## File Upload Flow

```mermaid
sequenceDiagram
    participant User
    participant CLI as furl CLI
    participant Config as ConfigManager
    participant Crypto as Encryption
    participant Filebin as Filebin Server
    participant atServer as atPlatform

    User->>CLI: furl @recipient file.pdf 2h
    CLI->>Config: resolveFilebinUrl()
    
    alt Has private override
        Config-->>CLI: User's custom URL
    else Has public config
        Config->>atServer: GET public:filebin.furl@furl
        atServer-->>Config: Org filebin URL
        Config-->>CLI: Org URL
    else Default
        Config-->>CLI: https://filebin.net
    end
    
    CLI->>Crypto: Generate ChaCha20 key + nonce
    CLI->>Crypto: Generate 9-char PIN
    CLI->>Crypto: Encrypt file (streaming)
    Crypto-->>CLI: Encrypted blob + SHA-512 hash
    
    CLI->>Filebin: POST /encrypted/file.pdf.encrypted
    Filebin-->>CLI: 201 Created
    
    CLI->>atServer: PUT private:_furl_{uuid}.metadata@recipient
    Note over CLI,atServer: Metadata: {key, nonce, hash, url, ttl}
    atServer-->>CLI: Success
    
    CLI-->>User: Share URL + PIN
    Note over User: https://furl.host?atSign=@recipient&key=_furl_xxx<br/>PIN: !Pa(MRMSV
```

## File Download Flow

```mermaid
sequenceDiagram
    participant User
    participant CLI as furl CLI
    participant atServer as atPlatform
    participant Filebin as Filebin Server
    participant Crypto as Decryption

    User->>CLI: furl receive <url> <pin>
    CLI->>CLI: Parse URL (extract atSign + key)
    CLI->>CLI: Derive ChaCha20 key from PIN
    
    CLI->>atServer: Authenticate as @user
    CLI->>atServer: GET private:{key}.metadata@user
    atServer-->>CLI: Encrypted metadata
    
    CLI->>Crypto: Decrypt metadata with PIN-derived key
    Crypto-->>CLI: {fileUrl, key, nonce, hash, filename}
    
    CLI->>Filebin: GET {fileUrl}
    Filebin-->>CLI: Encrypted file blob
    
    CLI->>Crypto: Decrypt with ChaCha20 (streaming)
    Crypto-->>CLI: Decrypted file
    
    CLI->>Crypto: Verify SHA-512 hash
    
    alt Hash matches
        Crypto-->>CLI: ✓ Valid
        CLI->>User: Save file to disk
        User-->>CLI: ✓ File received
    else Hash mismatch
        Crypto-->>CLI: ✗ Corrupted
        CLI-->>User: Error: File integrity check failed
    end
```

## Configuration Architecture

### Three-Tier Resolution

```mermaid
graph LR
    A[Upload Request] --> B{Check Private Override}
    B -->|Found| C[Use private:filebin_override.furl@user]
    B -->|Not Found| D{Check Public Config}
    D -->|Found| E[Use public:filebin.furl@furl or @org]
    D -->|Not Found| F[Use Default: https://filebin.net]
    
    C --> G[Upload to Resolved URL]
    E --> G
    F --> G
    
    style C fill:#e1f5ff
    style E fill:#f0e1ff
    style F fill:#fff4e1
```

### Configuration Storage

```mermaid
graph TB
    subgraph "Private Override (User-level)"
        A[private:filebin_override.furl@alice]
        A1[Value: url|config_atsign]
        A2[Example: https://my-filebin.com|@mycompany]
    end
    
    subgraph "Public Config (Org-level)"
        B[public:filebin.furl@furl]
        B1[Value: url]
        B2[Example: https://ck6agzxiog6kmb.atsign.com]
    end
    
    subgraph "Default Fallback"
        C[Hardcoded in Code]
        C1[Value: https://filebin.net]
    end
    
    A --> D[Highest Priority]
    B --> E[Medium Priority]
    C --> F[Lowest Priority]
    
    style A fill:#e1f5ff
    style B fill:#f0e1ff
    style C fill:#fff4e1
```

## Encryption Details

### Key Derivation and Storage

```mermaid
graph TB
    subgraph "Sender Side"
        A[Generate Random ChaCha20 Key<br/>256 bits] --> B[Generate Random Nonce<br/>96 bits]
        B --> C[Generate Strong PIN<br/>9 chars with special chars]
        C --> D[Derive AES Key from PIN<br/>PBKDF2 or similar]
        A --> E[Encrypt File with ChaCha20]
        B --> E
        E --> F[Calculate SHA-512 Hash]
        F --> G[Create Metadata Object]
        D --> G
        G --> H[Encrypt Metadata with PIN-derived Key]
        H --> I[Store on atPlatform<br/>private:_furl_uuid.metadata@recipient]
    end
    
    subgraph "Metadata Contents"
        J[file_url: https://filebin.net/xxx]
        K[chacha20_key: base64]
        L[chacha20_nonce: base64]
        M[file_hash: SHA-512 hex]
        N[original_filename: file.pdf]
        O[ttl: 7200 seconds]
    end
    
    I --> J
    I --> K
    I --> L
    I --> M
    I --> N
    I --> O
    
    style E fill:#e1f5ff
    style H fill:#f0e1ff
```

### Security Properties

1. **End-to-End Encryption**: Files are encrypted on sender's device, only decrypted on recipient's device
2. **Zero-Knowledge**: Filebin server never sees plaintext or decryption keys
3. **Secure Key Exchange**: Decryption metadata stored in recipient's private atKey space
4. **PIN Protection**: Additional layer requires out-of-band PIN sharing
5. **Integrity Verification**: SHA-512 hash ensures file wasn't tampered with
6. **Time-Limited**: Automatic expiration prevents long-term exposure

## Cache Management

### Remote Fetch Strategy

To prevent stale cached values, all configuration reads and writes use `useRemoteAtServer = true`:

```dart
// GET operations - Always fetch from remote
final getRequestOptions = GetRequestOptions()..useRemoteAtServer = true;
final result = await atClient.get(atKey, getRequestOptions: getRequestOptions);

// PUT operations - Always write to remote
final putRequestOptions = PutRequestOptions()..useRemoteAtServer = true;
await atClient.put(atKey, value, putRequestOptions: putRequestOptions);

// Brief sync delay for secondary server propagation
await Future.delayed(Duration(milliseconds: 500));
```

This ensures:
- Users immediately see updated filebin configurations
- No cache staleness when admin publishes new URLs
- Consistent behavior across all devices

## CLI Commands

### Upload
```bash
furl @recipient file.pdf 2h [-v] [-q] [-s URL] [-m "message"]
```

### Receive
```bash
furl receive <url> <pin> [-v] [-q] [-o /path/to/output]
```

### Configure Personal Override
```bash
furl set-filebin @alice https://my-filebin.com [@orgname] [-v]
```

### Publish Org-Wide Config
```bash
furl publish-filebin @orgname https://org-filebin.com [-v]
```

## Data Flow Summary

### Upload
1. User provides file, recipient atSign, and TTL
2. Resolve filebin URL from configuration (3-tier)
3. Generate ChaCha20 encryption key and nonce
4. Generate strong PIN for additional security
5. Encrypt file using streaming ChaCha20
6. Calculate SHA-512 hash for integrity
7. Upload encrypted blob to filebin server
8. Encrypt and store metadata in recipient's atKey
9. Return URL and PIN to sender

### Download
1. User provides furl URL and PIN
2. Parse URL to extract recipient atSign and metadata key
3. Authenticate to atPlatform as recipient
4. Fetch encrypted metadata from atKey
5. Decrypt metadata using PIN-derived key
6. Download encrypted file from filebin server
7. Decrypt file using ChaCha20 key from metadata
8. Verify SHA-512 hash matches
9. Save decrypted file to disk

## Technology Stack

- **Language**: Dart (CLI & Flutter)
- **Encryption**: ChaCha20 (via `encrypt` package)
- **Hashing**: SHA-512 (via `crypto` package)
- **atPlatform**: Decentralized key-value storage
- **File Storage**: Configurable filebin server (HTTP/HTTPS)
- **UI**: Flutter (mobile/desktop apps)

## Security Considerations

### Threats Mitigated
- ✅ Man-in-the-middle attacks (E2E encryption)
- ✅ Server compromise (encrypted blobs only)
- ✅ Unauthorized access (PIN + atPlatform auth)
- ✅ Data tampering (SHA-512 verification)
- ✅ Long-term exposure (automatic expiration)

### Threat Model
- ❌ Sender/recipient device compromise (out of scope)
- ❌ PIN shared insecurely (user responsibility)
- ❌ Quantum computing attacks (ChaCha20 is quantum-resistant)

## Future Enhancements

- [ ] Multiple file support (ZIP compression)
- [ ] Compression before encryption
- [ ] Resumable uploads/downloads
- [ ] Web-based receiver (no CLI needed)
- [ ] File sharing groups
- [ ] Audit logs
- [ ] Custom TTL policies per org
- [ ] S3-compatible storage backend

## Development

### Project Structure
```
furl/
├── bin/
│   ├── furl.dart              # CLI entry point
│   └── furl_server.dart       # Server component
├── lib/
│   ├── config_manager.dart    # Configuration storage
│   ├── filebin_resolver.dart  # URL resolution
│   └── validation.dart        # Input validation
├── flutter_furl/
│   └── lib/
│       ├── core/
│       │   └── services/      # Business logic
│       └── features/
│           ├── send/          # Upload UI
│           ├── receive/       # Download UI
│           └── settings/      # Config UI
└── test/
    └── furl_test.dart         # Unit tests
```

### Building
```bash
# CLI
dart compile exe bin/furl.dart -o furl

# Flutter app
cd flutter_furl
flutter build apk        # Android
flutter build ios        # iOS
flutter build macos      # macOS
flutter build windows    # Windows
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

See [LICENSE](LICENSE) file for details.
