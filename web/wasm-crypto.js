// WASM Crypto Integration for Furl
// This module provides high-performance AES-CTR decryption using WebAssembly

class WasmCrypto {
    constructor() {
        this.wasmModule = null;
        this.initialized = false;
    }

    /**
     * Initialize the WASM module
     * @returns {Promise<boolean>} True if initialization succeeded
     */
    async init() {
        try {
            // Dynamic import of the WASM module
            const wasmModule = await import('./wasm/furl_crypto.js');
            await wasmModule.default(); // Initialize WASM
            
            this.wasmModule = wasmModule;
            this.initialized = true;
            
            console.log('WASM Crypto module initialized successfully');
            console.log('Version:', wasmModule.get_version());
            console.log('Test:', wasmModule.test_wasm());
            
            return true;
        } catch (error) {
            console.warn('Failed to initialize WASM module:', error);
            console.log('Falling back to WebCrypto API');
            return false;
        }
    }

    /**
     * Check if WASM is available and initialized
     * @returns {boolean}
     */
    isAvailable() {
        return this.initialized && this.wasmModule !== null;
    }

    /**
     * Create a ChaCha20 streaming cipher state
     * @param {Uint8Array} key - 32-byte ChaCha20 key
     * @param {Uint8Array} nonce - 12-byte ChaCha20 nonce
     * @returns {Promise<Object>} Cipher state object
     */
    async createChaCha20Stream(key, nonce) {
        if (!this.isAvailable()) {
            throw new Error('WASM module not initialized');
        }

        try {
            console.log('WASM: Creating ChaCha20 stream cipher state');
            const state = this.wasmModule.create_chacha20_stream(key, nonce);
            console.log('WASM: ChaCha20 stream state created');
            return state;
        } catch (error) {
            console.error('WASM ChaCha20 stream creation failed:', error);
            throw error;
        }
    }

    /**
     * Decrypt a single chunk using streaming ChaCha20
     * @param {Object} cipherState - Cipher state from createChaCha20Stream
     * @param {Uint8Array} chunk - Encrypted chunk
     * @returns {Promise<Uint8Array>} Decrypted chunk
     */
    async decryptChaCha20Chunk(cipherState, chunk) {
        if (!this.isAvailable()) {
            throw new Error('WASM module not initialized');
        }

        try {
            const result = this.wasmModule.decrypt_chacha20_chunk(cipherState, chunk);
            return result;
        } catch (error) {
            console.error('WASM ChaCha20 chunk decryption failed:', error);
            throw error;
        }
    }

    /**
     * Decrypt data using WASM ChaCha20
     * @param {Uint8Array} key - 32-byte ChaCha20 key
     * @param {Uint8Array} nonce - 12-byte ChaCha20 nonce
     * @param {Uint8Array} encryptedData - Encrypted data
     * @returns {Promise<Uint8Array>} Decrypted data
     */
    async decryptChaCha20(key, nonce, encryptedData) {
        if (!this.isAvailable()) {
            throw new Error('WASM module not initialized');
        }

        try {
            console.log(`WASM: ChaCha20 decrypting ${encryptedData.length} bytes`);
            const result = this.wasmModule.decrypt_chacha20(key, nonce, encryptedData);
            console.log(`WASM: Successfully decrypted ${result.length} bytes`);
            return result;
        } catch (error) {
            console.error('WASM ChaCha20 decryption failed:', error);
            throw error;
        }
    }

    /**
     * Decrypt large data using chunked WASM ChaCha20
     * @param {Uint8Array} key - 32-byte ChaCha20 key
     * @param {Uint8Array} nonce - 12-byte ChaCha20 nonce
     * @param {Uint8Array} encryptedData - Encrypted data
     * @param {number} chunkSize - Chunk size in bytes (default: 2MB)
     * @param {Function} progressCallback - Progress callback function
     * @returns {Promise<Uint8Array>} Decrypted data
     */
    async decryptChaCha20Chunked(key, nonce, encryptedData, chunkSize = 2 * 1024 * 1024, progressCallback = null) {
        if (!this.isAvailable()) {
            throw new Error('WASM module not initialized');
        }

        try {
            console.log(`WASM: ChaCha20 chunked decrypting ${encryptedData.length} bytes`);
            
            // Create a wrapper for the progress callback
            const wasmProgressCallback = progressCallback ? 
                (progress) => progressCallback(progress) : null;

            const result = this.wasmModule.decrypt_chacha20_chunked(
                key, 
                nonce, 
                encryptedData, 
                chunkSize,
                wasmProgressCallback
            );
            
            console.log(`WASM: Successfully decrypted ${result.length} bytes in chunks`);
            return result;
        } catch (error) {
            console.error('WASM ChaCha20 chunked decryption failed:', error);
            throw error;
        }
    }

    /**
     * Decrypt data using WASM AES-CTR
     * @param {Uint8Array} key - 32-byte AES key
     * @param {Uint8Array} iv - 16-byte initialization vector
     * @param {Uint8Array} encryptedData - Encrypted data
     * @returns {Promise<Uint8Array>} Decrypted data
     */
    async decryptAesCtr(key, iv, encryptedData) {
        if (!this.isAvailable()) {
            throw new Error('WASM module not initialized');
        }

        try {
            console.log(`WASM: Decrypting ${encryptedData.length} bytes`);
            const result = this.wasmModule.decrypt_aes_ctr(key, iv, encryptedData);
            console.log(`WASM: Successfully decrypted ${result.length} bytes`);
            return result;
        } catch (error) {
            console.error('WASM decryption failed:', error);
            throw error;
        }
    }

    /**
     * Decrypt large data using chunked WASM AES-CTR
     * @param {Uint8Array} key - 32-byte AES key
     * @param {Uint8Array} iv - 16-byte initialization vector
     * @param {Uint8Array} encryptedData - Encrypted data
     * @param {number} chunkSize - Chunk size in bytes (default: 2MB)
     * @param {Function} progressCallback - Progress callback function
     * @returns {Promise<Uint8Array>} Decrypted data
     */
    async decryptAesCtrChunked(key, iv, encryptedData, chunkSize = 2 * 1024 * 1024, progressCallback = null) {
        if (!this.isAvailable()) {
            throw new Error('WASM module not initialized');
        }

        try {
            console.log(`WASM: Chunked decrypting ${encryptedData.length} bytes`);
            
            // Create a wrapper for the progress callback
            const wasmProgressCallback = progressCallback ? 
                (progress) => progressCallback(progress) : null;

            const result = this.wasmModule.decrypt_aes_ctr_chunked(
                key, 
                iv, 
                encryptedData, 
                chunkSize,
                wasmProgressCallback
            );
            
            console.log(`WASM: Successfully decrypted ${result.length} bytes in chunks`);
            return result;
        } catch (error) {
            console.error('WASM chunked decryption failed:', error);
            throw error;
        }
    }
}

// Create global instance
const wasmCrypto = new WasmCrypto();

// Pure WASM decryption function - no JavaScript fallbacks
async function hybridDecryptFile(key, ivOrNonce, encryptedData, cipher = 'aes-ctr', progressCallback = null) {
    console.log(`Pure WASM decrypting with cipher: ${cipher}`);
    
    // Ensure WASM is available - no fallbacks
    if (!wasmCrypto.isAvailable()) {
        throw new Error('WASM module required but not available. Please ensure WASM is supported and loaded.');
    }
    
    if (cipher === 'chacha20') {
        // Use ChaCha20 decryption
        try {
            // Always use chunked decryption for consistent behavior and progress tracking
            console.log('Using WASM ChaCha20 chunked decryption');
            return await wasmCrypto.decryptChaCha20Chunked(key, ivOrNonce, encryptedData, undefined, progressCallback);
        } catch (error) {
            console.error('WASM ChaCha20 decryption failed:', error);
            throw new Error('ChaCha20 decryption failed: ' + error.message);
        }
    } else {
        // Use AES-CTR with WASM only
        try {
            console.log('Using WASM AES-CTR chunked decryption');
            // Always use chunked decryption for consistent memory usage and progress
            return await wasmCrypto.decryptAesCtrChunked(key, ivOrNonce, encryptedData, undefined, progressCallback);
        } catch (error) {
            console.error('WASM AES-CTR decryption failed:', error);
            throw new Error('AES-CTR decryption failed: ' + error.message);
        }
    }
}

// Legacy function for backward compatibility - now redirects to pure WASM
async function hybridDecryptAesCtr(key, iv, encryptedData, progressCallback = null) {
    return await hybridDecryptFile(key, iv, encryptedData, 'aes-ctr', progressCallback);
}

// Initialize WASM when module loads
(async () => {
    await wasmCrypto.init();
})();

// Export for use in other modules
window.wasmCrypto = wasmCrypto;
window.hybridDecryptFile = hybridDecryptFile;
window.hybridDecryptAesCtr = hybridDecryptAesCtr;
