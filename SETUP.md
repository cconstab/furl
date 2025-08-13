# Furl - Production Setup Guide

## Prerequisites

Before using Furl in production, you need to set up your atSign:

1. **Get an atSign**: Sign up at https://my.atsign.com/
2. **Activate your atSign**: Run `at activate @yoursign` 
3. **Update the code**: Replace `@cconstab` with your actual atSign in `bin/furl.dart`

## How it Works

### Sender Side (CLI)
```bash
dart run bin/furl.dart myfile.pdf 3600
```

This will:
1. Generate a random AES-256 key and encrypt the file
2. Generate a 9-character alphanumeric PIN
3. Encrypt the AES key with the PIN
4. Upload the encrypted file to a file hosting service
5. Store the encrypted AES key and file URL in a **public atKey** with leading underscore:
   - Key name: `_furl_${timestamp}` (invisible to scan verb)
   - Public: accessible without authentication
   - TTL: expires after specified time
6. Print a URL containing the atSign and key name

### Recipient Side (Web)
The recipient visits the URL and:
1. Enters the 9-character PIN
2. System looks up the atServer for the sender's atSign
3. Fetches the public atKey containing encrypted secrets
4. Uses PIN to decrypt the AES key
5. Downloads and decrypts the file

## Security Model

- **File encryption**: AES-256 with ephemeral keys
- **Key protection**: AES key encrypted with PIN-derived key
- **Public storage**: Only encrypted metadata stored in atPlatform
- **No file content**: Files never stored in atPlatform
- **Auto-expiration**: Secrets automatically expire after TTL
- **Scan protection**: Leading underscore makes keys invisible to scan

## Current Status

The implementation is complete but requires:
1. A real atSign setup for the sender
2. A reliable file hosting service (currently simulated)
3. Web hosting for the recipient interface

The code demonstrates the complete flow and security model using the atPlatform correctly for secret storage only.
