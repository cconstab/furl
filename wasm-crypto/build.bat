@echo off
echo Building WASM module...

REM Build the WASM module
wasm-pack build --target web --out-dir ../web/wasm

echo WASM module built successfully!
echo Files generated in ../web/wasm/
