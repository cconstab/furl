# Furl Security Design and Process Flow

## Overview

Furl is a secure file sharing system that combines multiple layers of encryption to ensure that files are protected both in transit and at rest, with client-side decryption to maintain privacy.

## Security Architecture

### 1. Multi-Layer Encryption Model

```
Original File → AES-256 Encryption → Upload to Public Storage
                    ↓
PIN-Protected AES Key → atPlatform Storage → Client-Side Decryption
```

### 2. Key Components

- **AES-256 File Encryption**: Files are encrypted with a randomly generated 256-bit AES key
- **PIN-Based Key Protection**: The AES key itself is encrypted using a PIN-derived key
- **Public Storage**: Encrypted files are stored on public services (filebin.net)
- **Metadata Storage**: Encrypted keys and metadata are stored on atPlatform
- **Client-Side Decryption**: All decryption happens in the recipient's browser

## Process Flow

### Upload Process (Sender)

1. **File Preparation**
   - Generate random 256-bit AES key
   - Generate random 128-bit IV (Initialization Vector)
   - Generate 9-character alphanumeric PIN

2. **File Encryption**
   ```
   Encrypted File = AES-256-CBC(Original File, AES Key, File IV)
   ```

3. **Key Protection**
   - Generate random 64-bit salt
   - Derive encryption key from PIN: `PIN Key = SHA256(PIN bytes + Salt bytes)`
   - Generate random 128-bit IV for key encryption
   - Encrypt the AES key: `Encrypted AES Key = AES-256-CBC(AES Key, PIN Key, Key IV)`

4. **Storage**
   - Upload encrypted file to filebin.net (public, anonymous storage)
   - Store metadata on atPlatform as public atKey:
     ```json
     {
       "file_url": "https://filebin.net/...",
       "aes_key": "base64(Encrypted AES Key)",
       "aes_key_iv": "base64(Key IV)",
       "aes_key_salt": "base64(Salt)",
       "file_iv": "base64(File IV)",
       "file_name": "original_filename.ext"
     }
     ```

5. **Share**
   - Provide recipient with:
     - Web interface URL with atSign and key parameters
     - PIN (communicated separately for security)

### Download Process (Recipient)

1. **Access Web Interface**
   - Navigate to URL: `http://localhost:8081/furl.html?atSign=@user&key=_furl_xxxxx`

2. **Retrieve Metadata**
   - Web interface calls API: `/fetch/{atSign}/{keyName}`
   - API queries atDirectory for atServer location
   - API fetches encrypted metadata from atServer

3. **PIN Entry and Key Derivation**
   - User enters 9-character PIN in browser
   - Browser derives PIN key: `PIN Key = SHA256(PIN bytes + Salt bytes)`
   - Browser decrypts AES key: `AES Key = AES-256-CBC-DECRYPT(Encrypted AES Key, PIN Key, Key IV)`

4. **File Download and Decryption**
   - Browser downloads encrypted file via API proxy: `/download?url=...`
   - Browser decrypts file: `Original File = AES-256-CBC-DECRYPT(Encrypted File, AES Key, File IV)`
   - Browser triggers automatic download of decrypted file

## Role of the PIN

### Security Purpose

The PIN serves as a **shared secret** that enables secure key exchange without requiring pre-shared cryptographic keys. Here's why it's critical:

1. **Key Protection**: The PIN protects the AES encryption key, ensuring that even if someone gains access to the atPlatform metadata, they cannot decrypt the file without the PIN.

2. **Zero-Knowledge Architecture**: The PIN never leaves the recipient's browser. The server never sees or stores the PIN, maintaining a zero-knowledge security model.

3. **Access Control**: Only someone with both the URL and the PIN can decrypt the file, providing two-factor access control.

4. **Forward Secrecy**: Each file uses a unique AES key and PIN, so compromise of one file doesn't affect others.

### PIN Characteristics

- **Length**: 9 characters (alphanumeric) provides ~60 bits of entropy
- **Generation**: Cryptographically random using Dart's secure random generator
- **Scope**: Single-use per file, not reused across multiple files
- **Transport**: Communicated out-of-band (separate from the URL) for security

## Security Benefits

### 1. Defense in Depth

- **Layer 1**: File is encrypted with AES-256 before upload
- **Layer 2**: AES key is encrypted with PIN-derived key
- **Layer 3**: Metadata is stored separately from file data
- **Layer 4**: PIN is communicated separately from URL

### 2. Privacy Protection

- **Server-Side**: Servers never see plaintext files or PINs
- **Client-Side**: All decryption happens in recipient's browser
- **Zero-Knowledge**: Service providers cannot decrypt files even if they wanted to

### 3. Compromise Resistance

- **File Storage Breach**: Encrypted files are useless without the AES key
- **Metadata Breach**: Encrypted AES keys are useless without the PIN
- **URL Interception**: URL alone cannot be used to decrypt files
- **PIN Interception**: PIN alone cannot be used without the URL

## Attack Resistance

### What Attackers Would Need

To decrypt a file, an attacker would need **ALL** of the following:
1. The complete URL (containing atSign and key identifier)
2. The 9-character PIN
3. Access to query the atPlatform for metadata
4. Access to download from filebin.net

### What Each Component Alone Reveals

- **URL only**: Reveals which atSign and key, but cannot access encrypted data
- **PIN only**: Useless without the corresponding encrypted AES key
- **Encrypted file only**: Cannot be decrypted without the AES key
- **Metadata only**: Contains encrypted AES key, but requires PIN to decrypt

## Implementation Security

### Key Derivation

The system uses a simple but effective key derivation:
```
PIN Key = SHA256(PIN_bytes || Salt_bytes)
```

This could be enhanced with PBKDF2 or Argon2 for additional security against brute force attacks.

### Cryptographic Primitives

- **Symmetric Encryption**: AES-256 in CBC mode
- **Key Generation**: Cryptographically secure random number generator
- **Hashing**: SHA-256 for key derivation
- **Padding**: PKCS#7 padding for block cipher

### Browser Security

- **Same-Origin Policy**: API endpoints use CORS to control access
- **Memory Management**: CryptoJS handles cryptographic operations securely
- **No Storage**: No sensitive data is stored in browser localStorage/sessionStorage

## Conclusion

The PIN serves as the critical link in a multi-layered security architecture that ensures:
1. Files are protected with strong encryption
2. Keys are protected by user-controlled secrets
3. Decryption is performed client-side for maximum privacy
4. Multiple independent factors are required for successful decryption

This design provides strong security while maintaining usability, allowing secure file sharing without requiring complex key management infrastructure.
