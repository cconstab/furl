#!/bin/bash

echo "Building WASM module..."

# Build the WASM module
wasm-pack build --target web --out-dir ../web/wasm --scope cconstab

echo "WASM module built successfully!"
echo "Files generated in ../web/wasm/"
