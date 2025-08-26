# Furl Test Suite

This directory contains comprehensive tests for the Furl secure file sharing application.

## Test Organization

### Core Test Files

- **`crypto_test.dart`** - Cryptographic functions and security tests
- **`server_test.dart`** - HTTP server functionality tests (tagged as e2e)  
- **`e2e_test.dart`** - End-to-end integration tests
- **`performance_test.dart`** - Performance and stress tests
- **`cli_validation_test.dart`** - Command-line interface validation tests
- **`furl_test.dart`** - Original security and integration tests

## Running Tests

### Quick Start

```bash
# Run all tests
dart test

# Run fast test suite (crypto + basic integration)
./run_tests.sh fast

# Run specific test types
./run_tests.sh crypto
./run_tests.sh server
./run_tests.sh integration
```

### Test Categories

#### 1. Cryptographic Tests (`crypto_test.dart`)
Tests core encryption, hashing, and security functions:
- AES-CTR encryption/decryption
- SHA-512 hash calculations
- PIN-based key derivation
- Large file handling
- Edge cases and error handling

#### 2. Server Tests (`server_test.dart`)
Tests HTTP server functionality:
- Health check endpoints
- Static file serving
- Concurrent request handling
- Error responses and CORS
- Port configuration

#### 3. Integration Tests (`e2e_test.dart`)
Tests complete workflows:
- CLI basic operations
- File hash verification
- Binary file handling
- Server startup and API responses

#### 4. Performance Tests (`performance_test.dart`)
Tests system performance:
- Encryption speed with various file sizes
- Memory usage monitoring
- Concurrent operation handling
- Stress testing under load

#### 5. CLI Validation Tests (`cli_validation_test.dart`)
Tests command-line interface:
- Argument validation
- atSign format checking
- Duration format validation
- Error message handling

## Test Runner Script

The `run_tests.sh` script provides convenient test execution:

```bash
./run_tests.sh [test_type]
```

Available test types:
- `unit/crypto` - Cryptographic function tests
- `server` - Server functionality tests
- `integration/e2e` - End-to-end integration tests
- `performance` - Performance and stress tests
- `cli` - CLI argument validation tests
- `original` - Original security tests
- `fast` - Quick test suite (crypto + basic integration)
- `all` - All tests (default)

## VS Code Integration

The `.vscode/` directory contains:
- **`settings.json`** - Dart test configuration
- **`tasks.json`** - Pre-defined test tasks

Available VS Code tasks:
- `Ctrl+Shift+P` → "Tasks: Run Task" → Select test suite

## Test Configuration

### Environment Setup
Tests automatically:
- Create temporary directories for test files
- Find available ports for server tests
- Set appropriate timeouts
- Clean up resources after completion

### Timeouts
- Individual tests: 60 seconds
- Server startup: 20 seconds
- Integration tests: Variable based on complexity

### Test Data
Tests use:
- Temporary files (automatically cleaned up)
- Generated binary data
- Configurable file sizes
- Random test content

## Performance Expectations

### Encryption Performance
- 1KB files: < 100ms
- 1MB files: < 1 second
- 10MB files: < 10 seconds

### Server Performance
- Health checks: > 10 requests/second
- Concurrent requests: > 5 requests/second
- Memory usage: < 500MB increase under load

## Troubleshooting

### Common Issues

1. **Port conflicts**: Tests automatically find available ports
2. **Timeout failures**: Increase timeout in `run_tests.sh`
3. **Memory issues**: Run tests individually instead of all at once
4. **File permission errors**: Ensure write access to temp directories

### Debug Mode

For detailed debugging:
```bash
dart test --chain-stack-traces
```

### Running Specific Tests

```bash
# Run specific test group
dart test test/crypto_test.dart --name="AES-CTR"

# Run with verbose output
dart test test/server_test.dart --reporter=expanded
```

## Contributing

When adding new tests:
1. Follow the existing file naming convention
2. Include both positive and negative test cases
3. Add appropriate timeout configurations
4. Include cleanup in `tearDown()` methods
5. Update this README with new test descriptions

## Test Coverage

The test suite covers:
- ✅ Cryptographic operations
- ✅ File I/O operations
- ✅ HTTP server functionality
- ✅ CLI argument parsing
- ✅ Error handling
- ✅ Performance characteristics
- ✅ Concurrent operations
- ✅ Memory management

## Dependencies

Test dependencies (from `pubspec.yaml`):
- `test: ^1.24.0` - Core testing framework
- `dio: ^5.4.0` - HTTP client for server tests
- `crypto: ^3.0.3` - Cryptographic operations
- `encrypt: ^5.0.3` - Encryption library testing
