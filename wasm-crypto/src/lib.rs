use wasm_bindgen::prelude::*;
use aes::Aes256;
use ctr::Ctr128BE;
use ctr::cipher::{KeyIvInit, StreamCipher};
use js_sys::Uint8Array;
use web_sys::console;

// Use wee_alloc for smaller binary size
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// Type alias for AES-256-CTR
type Aes256Ctr = Ctr128BE<Aes256>;

#[wasm_bindgen]
extern "C" {
    fn alert(s: &str);
}

// Macro for logging to console
macro_rules! log {
    ( $( $t:tt )* ) => {
        console::log_1(&format!( $( $t )* ).into());
    }
}

#[wasm_bindgen]
pub fn init_panic_hook() {
    console_error_panic_hook::set_once();
}

/// Decrypt data using AES-256-CTR mode
/// 
/// # Arguments
/// * `key` - 32-byte AES key as Uint8Array
/// * `iv` - 16-byte initialization vector as Uint8Array  
/// * `encrypted_data` - Encrypted data as Uint8Array
/// 
/// # Returns
/// Decrypted data as Uint8Array
#[wasm_bindgen]
pub fn decrypt_aes_ctr(
    key: &Uint8Array,
    iv: &Uint8Array, 
    encrypted_data: &Uint8Array
) -> Result<Uint8Array, JsValue> {
    // Validate input sizes
    if key.length() != 32 {
        return Err(JsValue::from_str(&format!("Invalid key size: expected 32 bytes, got {}", key.length())));
    }
    
    if iv.length() != 16 {
        return Err(JsValue::from_str(&format!("Invalid IV size: expected 16 bytes, got {}", iv.length())));
    }

    // Convert JS Uint8Arrays to Rust Vec<u8>
    let key_bytes: Vec<u8> = key.to_vec();
    let iv_bytes: Vec<u8> = iv.to_vec();
    let mut data_bytes: Vec<u8> = encrypted_data.to_vec();

    log!("WASM: Decrypting {} bytes with AES-256-CTR", data_bytes.len());
    log!("WASM: Key size: {} bytes", key_bytes.len());
    log!("WASM: IV size: {} bytes", iv_bytes.len());

    // Create cipher
    let mut cipher = match Aes256Ctr::new(
        (&key_bytes[..]).try_into().map_err(|_| JsValue::from_str("Invalid key format"))?,
        (&iv_bytes[..]).try_into().map_err(|_| JsValue::from_str("Invalid IV format"))?
    ) {
        cipher => cipher,
    };

    // Decrypt in place (CTR mode encryption = decryption)
    cipher.apply_keystream(&mut data_bytes);

    log!("WASM: Successfully decrypted {} bytes", data_bytes.len());

    // Convert back to Uint8Array
    Ok(Uint8Array::from(&data_bytes[..]))
}

/// Decrypt data in chunks to handle large files efficiently
/// 
/// # Arguments
/// * `key` - 32-byte AES key as Uint8Array
/// * `iv` - 16-byte initialization vector as Uint8Array  
/// * `encrypted_data` - Encrypted data as Uint8Array
/// * `chunk_size` - Size of chunks to process (default: 2MB)
/// * `progress_callback` - Optional callback for progress updates
/// 
/// # Returns
/// Decrypted data as Uint8Array
#[wasm_bindgen]
pub fn decrypt_aes_ctr_chunked(
    key: &Uint8Array,
    iv: &Uint8Array,
    encrypted_data: &Uint8Array,
    chunk_size: Option<usize>,
    progress_callback: Option<js_sys::Function>
) -> Result<Uint8Array, JsValue> {
    // Validate input sizes
    if key.length() != 32 {
        return Err(JsValue::from_str(&format!("Invalid key size: expected 32 bytes, got {}", key.length())));
    }
    
    if iv.length() != 16 {
        return Err(JsValue::from_str(&format!("Invalid IV size: expected 16 bytes, got {}", iv.length())));
    }

    let key_bytes: Vec<u8> = key.to_vec();
    let iv_bytes: Vec<u8> = iv.to_vec();
    let data_bytes: Vec<u8> = encrypted_data.to_vec();
    let chunk_size = chunk_size.unwrap_or(2 * 1024 * 1024); // Default 2MB chunks

    log!("WASM: Chunked decryption of {} bytes in {} byte chunks", data_bytes.len(), chunk_size);

    let mut result = Vec::with_capacity(data_bytes.len());
    let total_chunks = (data_bytes.len() + chunk_size - 1) / chunk_size;

    for (chunk_idx, chunk) in data_bytes.chunks(chunk_size).enumerate() {
        // Calculate the counter offset for this chunk
        let blocks_processed = (chunk_idx * chunk_size) / 16;
        let mut chunk_iv = iv_bytes.clone();
        
        // Increment the counter by blocks_processed
        increment_counter(&mut chunk_iv, blocks_processed);

        // Create cipher for this chunk
        let mut cipher = Aes256Ctr::new(
            (&key_bytes[..]).try_into().map_err(|_| JsValue::from_str("Invalid key format"))?,
            (&chunk_iv[..]).try_into().map_err(|_| JsValue::from_str("Invalid IV format"))?
        );

        // Decrypt this chunk
        let mut chunk_data = chunk.to_vec();
        cipher.apply_keystream(&mut chunk_data);
        result.extend_from_slice(&chunk_data);

        // Call progress callback if provided
        if let Some(ref callback) = progress_callback {
            let progress = ((chunk_idx + 1) as f64 / total_chunks as f64 * 100.0) as u32;
            let _ = callback.call1(&JsValue::NULL, &JsValue::from(progress));
        }

        log!("WASM: Processed chunk {}/{} ({} bytes)", chunk_idx + 1, total_chunks, chunk.len());
    }

    log!("WASM: Successfully decrypted {} bytes in {} chunks", result.len(), total_chunks);

    Ok(Uint8Array::from(&result[..]))
}

/// Increment a 16-byte counter by the specified number of blocks
fn increment_counter(counter: &mut [u8], blocks: usize) {
    let mut carry = blocks;
    
    // Work from right to left (big-endian)
    for i in (0..counter.len()).rev() {
        if carry == 0 {
            break;
        }
        
        let sum = counter[i] as usize + (carry & 0xFF);
        counter[i] = (sum & 0xFF) as u8;
        carry >>= 8;
    }
}

/// Get version information
#[wasm_bindgen]
pub fn get_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Simple test function
#[wasm_bindgen]
pub fn test_wasm() -> String {
    "WASM module loaded successfully!".to_string()
}
