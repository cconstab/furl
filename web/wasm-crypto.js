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

// Enhanced decryption function that supports both ChaCha20 and AES-CTR with streaming
async function hybridDecryptFile(key, ivOrNonce, encryptedData, cipher = 'aes-ctr', progressCallback = null) {
    console.log(`Decrypting with cipher: ${cipher}`);
    
    if (cipher === 'chacha20') {
        // Use ChaCha20 decryption
        if (wasmCrypto.isAvailable()) {
            try {
                // For larger files, use chunked decryption to reduce memory usage
                if (encryptedData.length > 5 * 1024 * 1024) { // 5MB threshold
                    return await wasmCrypto.decryptChaCha20Chunked(key, ivOrNonce, encryptedData, undefined, progressCallback);
                } else {
                    return await wasmCrypto.decryptChaCha20(key, ivOrNonce, encryptedData);
                }
            } catch (error) {
                console.error('WASM ChaCha20 decryption failed:', error);
                throw new Error('ChaCha20 decryption failed: ' + error.message);
            }
        } else {
            throw new Error('WASM module not available for ChaCha20 decryption');
        }
    } else {
        // Default to AES-CTR (legacy support) with chunked processing for large files
        console.log('Using WebCrypto for AES-CTR decryption');
        
        // For large files, process in chunks to reduce memory pressure
        if (encryptedData.length > 10 * 1024 * 1024) { // 10MB threshold
            return await decryptAesCtrInChunks(key, ivOrNonce, encryptedData, progressCallback);
        } else {
            // Small files - process normally
            if (progressCallback) {
                progressCallback(50);
            }
            
            const decryptedArrayBuffer = await window.crypto.subtle.decrypt(
                {
                    name: 'AES-CTR',
                    counter: ivOrNonce,
                    length: 128
                },
                await window.crypto.subtle.importKey(
                    'raw',
                    key,
                    { name: 'AES-CTR' },
                    false,
                    ['decrypt']
                ),
                encryptedData
            );
            
            if (progressCallback) {
                progressCallback(100);
            }
            
            return new Uint8Array(decryptedArrayBuffer);
        }
    }
}

// Memory-efficient chunked AES-CTR decryption for large files
async function decryptAesCtrInChunks(key, initialIv, encryptedData, progressCallback = null) {
    console.log(`AES-CTR chunked decryption: ${encryptedData.length} bytes`);
    
    // Import the key once
    const cryptoKey = await window.crypto.subtle.importKey(
        'raw',
        key,
        { name: 'AES-CTR' },
        false,
        ['decrypt']
    );
    
    // Process in 2MB chunks to balance memory usage and performance
    const chunkSize = 2 * 1024 * 1024;
    const numChunks = Math.ceil(encryptedData.length / chunkSize);
    const decryptedChunks = [];
    
    // Track counter state
    let currentCounter = new Uint8Array(initialIv);
    
    for (let i = 0; i < numChunks; i++) {
        const start = i * chunkSize;
        const end = Math.min(start + chunkSize, encryptedData.length);
        const chunk = encryptedData.slice(start, end);
        
        // Decrypt this chunk
        const decryptedChunk = await window.crypto.subtle.decrypt(
            {
                name: 'AES-CTR',
                counter: currentCounter.slice(),
                length: 128
            },
            cryptoKey,
            chunk
        );
        
        decryptedChunks.push(new Uint8Array(decryptedChunk));
        
        // Advance counter for next chunk
        const blocksProcessed = Math.ceil(chunk.length / 16);
        currentCounter = incrementCounter(currentCounter, blocksProcessed);
        
        // Update progress
        const progress = Math.round(((i + 1) / numChunks) * 100);
        if (progressCallback) {
            progressCallback(progress);
        }
        
        // Allow other operations
        await new Promise(resolve => setTimeout(resolve, 0));
    }
    
    // Combine chunks efficiently
    const totalLength = decryptedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    
    for (const chunk of decryptedChunks) {
        result.set(chunk, offset);
        offset += chunk.length;
    }
    
    console.log(`AES-CTR chunked decryption completed: ${totalLength} bytes`);
    return result;
}

// Helper function to increment CTR counter
function incrementCounter(counter, blockCount) {
    const result = new Uint8Array(counter);
    let carry = blockCount;
    
    for (let i = result.length - 1; i >= 0 && carry > 0; i--) {
        const sum = result[i] + (carry & 0xFF);
        result[i] = sum & 0xFF;
        carry = Math.floor(carry / 256);
    }
    
    return result;
}

// Legacy function for backward compatibility
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
