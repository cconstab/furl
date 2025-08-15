# WASM Crypto Module Setup

## Prerequisites

1. **Install Rust**: Download from https://rustup.rs/
   ```
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Install wasm-pack**: 
   ```
   cargo install wasm-pack
   ```

## Building the WASM Module

1. Navigate to the wasm-crypto directory:
   ```
   cd wasm-crypto
   ```

2. Build the WASM module:
   ```bash
   # On Windows
   build.bat
   
   # On Linux/Mac
   ./build.sh
   ```

   Or manually:
   ```
   wasm-pack build --target web --out-dir ../web/wasm --scope cconstab
   ```

## Generated Files

After building, you'll have these files in `web/wasm/`:
- `furl_crypto.js` - JavaScript bindings
- `furl_crypto_bg.wasm` - WebAssembly binary
- `package.json` - NPM package info

## Usage in Browser

```javascript
import init, { decrypt_aes_ctr, decrypt_aes_ctr_chunked } from './wasm/furl_crypto.js';

// Initialize WASM module
await init();

// Use for decryption
const decryptedData = decrypt_aes_ctr(key, iv, encryptedData);
```

## Performance Benefits

- **Speed**: 2-10x faster than pure JavaScript
- **Memory**: More efficient memory usage
- **Threading**: Can be used with Web Workers
- **Size**: Smaller than equivalent JS crypto libraries
