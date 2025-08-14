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

// Enhanced decryption function that tries WASM first, falls back to WebCrypto
async function hybridDecryptAesCtr(key, iv, encryptedData, progressCallback = null) {
    // Try WASM first if available
    if (wasmCrypto.isAvailable()) {
        try {
            // For larger files, use chunked decryption
            if (encryptedData.length > 5 * 1024 * 1024) { // 5MB threshold
                return await wasmCrypto.decryptAesCtrChunked(key, iv, encryptedData, undefined, progressCallback);
            } else {
                return await wasmCrypto.decryptAesCtr(key, iv, encryptedData);
            }
        } catch (error) {
            console.warn('WASM decryption failed, falling back to WebCrypto:', error);
        }
    }

    // Fallback to WebCrypto
    console.log('Using WebCrypto fallback');
    
    if (progressCallback) {
        progressCallback(50); // Simulate progress for single operation
    }
    
    const decryptedArrayBuffer = await crypto.subtle.decrypt(
        {
            name: 'AES-CTR',
            counter: iv,
            length: 128
        },
        await crypto.subtle.importKey(
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

// Initialize WASM when module loads
(async () => {
    await wasmCrypto.init();
})();

// Export for use in other modules
window.wasmCrypto = wasmCrypto;
window.hybridDecryptAesCtr = hybridDecryptAesCtr;
