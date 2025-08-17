#!/bin/bash

# Test runner script for furl project
# Usage: ./run_tests.sh [test_type]
# test_type can be: unit, crypto, server, integration, performance, all

set -e

echo "🧪 Furl Test Runner"
echo "=================="

# Function to run specific test files
run_test() {
    local test_file="$1"
    local test_name="$2"
    
    echo "🔍 Running $test_name tests..."
    if dart test "$test_file"; then
        echo "✅ $test_name tests passed"
    else
        echo "❌ $test_name tests failed"
        return 1
    fi
    echo ""
}

# Function to run all tests with timeout
run_all_tests() {
    echo "🚀 Running all tests..."
    if timeout 300 dart test; then
        echo "✅ All tests completed successfully"
    else
        echo "⚠️  Some tests failed or timed out"
        return 1
    fi
}

# Main test execution
case "${1:-all}" in
    "unit"|"crypto")
        run_test "test/crypto_test.dart" "Cryptographic"
        ;;
    "server")
        run_test "test/server_test.dart" "Server"
        ;;
    "integration"|"e2e")
        run_test "test/e2e_test.dart" "Integration"
        ;;
    "performance"|"perf")
        run_test "test/performance_test.dart" "Performance"
        ;;
    "cli")
        run_test "test/cli_validation_test.dart" "CLI Validation"
        ;;
    "original")
        run_test "test/furl_test.dart" "Original Security"
        ;;
    "light")
        echo "🏃‍♂️ Running light test suite..."
        run_test "test/crypto_test.dart" "Cryptographic"
        run_test "test/e2e_test.dart" "Basic Integration"
        run_test "test/server_test.dart" "Server"
        ;;
    "fast")
        echo "🏃‍♂️ Running fast test suite..."
        run_test "test/crypto_test.dart" "Cryptographic"
        run_test "test/e2e_test.dart" "Basic Integration"
        ;;
    "all")
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [unit|server|integration|performance|cli|original|light|fast|all]"
        echo ""
        echo "Available test suites:"
        echo "  unit/crypto    - Cryptographic function tests"
        echo "  server         - Server functionality tests"
        echo "  integration/e2e - End-to-end integration tests"
        echo "  performance    - Performance and stress tests"
        echo "  cli            - CLI argument validation tests"
        echo "  original       - Original security tests"
        echo "  light          - Light test suite (crypto + integration + server)"
        echo "  fast           - Quick test suite (crypto + basic integration)"
        echo "  all            - All tests (default)"
        exit 1
        ;;
esac

echo "🎉 Test execution completed!"
