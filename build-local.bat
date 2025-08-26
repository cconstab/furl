@echo off
setlocal enabledelayedexpansion

REM Local build script for testing multi-platform compilation (Windows version)
REM This script mimics what the GitHub Actions workflow does

echo 🚀 Starting local furl build process...

REM Create build directory
if not exist build mkdir build

REM Check Dart installation
dart --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Dart SDK not found. Please install Dart.
    exit /b 1
)

echo ✓ Dart SDK found
dart --version

REM Install dependencies
echo 📦 Installing dependencies...
dart pub get

REM Run analysis
echo 🔍 Running code analysis...
dart analyze
if errorlevel 1 (
    echo ⚠ Code analysis issues found
) else (
    echo ✓ Code analysis passed
)

REM Run tests
echo 🧪 Running tests...
dart test
if errorlevel 1 (
    echo ⚠ Some tests failed
) else (
    echo ✓ Tests passed
)

REM Check formatting
echo 📝 Checking code formatting...
dart format --set-exit-if-changed .
if errorlevel 1 (
    echo ⚠ Code formatting issues found
) else (
    echo ✓ Code formatting is correct
)

REM Build executables
echo 🔨 Building executables...

REM Main furl executable
dart compile exe bin/furl.dart -o build/furl.exe
if errorlevel 1 (
    echo ✗ Failed to build furl executable
    exit /b 1
) else (
    echo ✓ Built furl executable
)

REM Server executable
dart compile exe bin/furl_server.dart -o build/furl-server.exe
if errorlevel 1 (
    echo ⚠ Failed to build furl-server executable
) else (
    echo ✓ Built furl-server executable
)

REM Copy web assets
echo 📁 Copying web assets...
if exist web (
    xcopy web build\web\ /E /I /Q >nul
    echo ✓ Copied web assets
)

if exist wasm-crypto (
    xcopy wasm-crypto build\wasm-crypto\ /E /I /Q >nul
    echo ✓ Copied wasm-crypto assets
)

REM Test executables
echo 🧪 Testing executables...
build\furl.exe --help >nul 2>&1
if errorlevel 1 (
    echo ⚠ furl executable test failed
) else (
    echo ✓ furl executable works
)

if exist build\furl-server.exe (
    build\furl-server.exe --help >nul 2>&1
    if errorlevel 1 (
        echo ⚠ furl-server executable test failed
    ) else (
        echo ✓ furl-server executable works
    )
)

REM Generate checksums
echo 🔐 Generating checksums...
cd build
certutil -hashfile furl.exe SHA256 > furl.sha256
if exist furl-server.exe (
    certutil -hashfile furl-server.exe SHA256 > furl-server.sha256
)
cd ..
echo ✓ Generated SHA256 checksums

REM Create archive (using PowerShell)
echo 📦 Creating archive...
powershell -Command "Compress-Archive -Path 'build\furl.exe', 'build\furl-server.exe', 'build\web', 'build\wasm-crypto', 'build\*.sha256' -DestinationPath 'build\furl-local-build.zip' -Force"

echo ✓ Build complete! Artifacts in build\ directory
echo.
echo 📊 Build Summary:
echo   - Executables: build\furl.exe, build\furl-server.exe
echo   - Web assets: build\web\
echo   - WASM crypto: build\wasm-crypto\
echo   - Checksums: build\*.sha256
echo   - Archive: build\furl-local-build.zip
echo.
echo 🚀 To test your build:
echo   build\furl.exe --help
echo   build\furl-server.exe
echo.
echo 🔐 To verify checksums:
echo   certutil -hashfile build\furl.exe SHA256
echo.
echo 🐳 To test Docker build:
echo   docker build -t furl-local .
echo   docker run -p 8080:8080 furl-local
