#!/bin/bash

# Local build script for testing multi-platform compilation
# This script mimics what the GitHub Actions workflow does

set -e

echo "🚀 Starting local furl build process..."

# Create build directory
mkdir -p build

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check Dart installation
if ! command -v dart &> /dev/null; then
    print_error "Dart SDK not found. Please install Dart."
    exit 1
fi

print_status "Dart SDK found: $(dart --version 2>&1 | head -n1)"

# Install dependencies
echo "📦 Installing dependencies..."
dart pub get

# Run analysis
echo "🔍 Running code analysis..."
if dart analyze; then
    print_status "Code analysis passed"
else
    print_warning "Code analysis issues found"
fi

# Run tests
echo "🧪 Running tests..."
if dart test; then
    print_status "Tests passed"
else
    print_warning "Some tests failed"
fi

# Check formatting
echo "📝 Checking code formatting..."
if dart format --set-exit-if-changed .; then
    print_status "Code formatting is correct"
else
    print_warning "Code formatting issues found"
fi

# Build executables
echo "🔨 Building executables..."

# Main furl executable
if dart compile exe bin/furl.dart -o build/furl; then
    print_status "Built furl executable"
else
    print_error "Failed to build furl executable"
    exit 1
fi

# Server executable
if dart compile exe bin/furl_server.dart -o build/furl-server; then
    print_status "Built furl-server executable"
else
    print_warning "Failed to build furl-server executable"
fi

# Copy web assets
echo "📁 Copying web assets..."
if [ -d "web" ]; then
    cp -r web build/
    print_status "Copied web assets"
fi

if [ -d "wasm-crypto" ]; then
    cp -r wasm-crypto build/
    print_status "Copied wasm-crypto assets"
fi

# Test executables
echo "🧪 Testing executables..."
if build/furl --help >/dev/null 2>&1; then
    print_status "furl executable works"
else
    print_warning "furl executable test failed"
fi

if [ -f "build/furl-server" ] && build/furl-server --help >/dev/null 2>&1; then
    print_status "furl-server executable works"
else
    print_warning "furl-server executable test failed"
fi

# Generate checksums
echo "🔐 Generating checksums..."
cd build
sha256sum furl > furl.sha256
if [ -f "furl-server" ]; then
    sha256sum furl-server > furl-server.sha256
fi
cd ..
print_status "Generated SHA256 checksums"

# Create archive
echo "📦 Creating archive..."
cd build
tar -czf furl-local-build.tar.gz furl furl-server web/ wasm-crypto/ *.sha256
cd ..

print_status "Build complete! Artifacts in build/ directory"
echo
echo "📊 Build Summary:"
echo "  - Executables: build/furl, build/furl-server"
echo "  - Web assets: build/web/"
echo "  - WASM crypto: build/wasm-crypto/"
echo "  - Checksums: build/*.sha256"
echo "  - Archive: build/furl-local-build.tar.gz"
echo
echo "🚀 To test your build:"
echo "  ./build/furl --help"
echo "  ./build/furl-server &"
echo
echo "🔐 To verify checksums:"
echo "  cd build && sha256sum -c furl.sha256"
echo
echo "🐳 To test Docker build:"
echo "  docker build -t furl-local ."
echo "  docker run -p 8080:8080 furl-local"
