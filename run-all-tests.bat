@echo off
REM Test runner script for furl - runs all tests including performance tests
REM Use this for local development and testing

echo 🧪 Running Furl Test Suite
echo ==========================

echo Running core tests (CI-compatible)...
dart test --exclude-tags=performance --exclude-tags=e2e
if %errorlevel% == 0 (
    echo ✅ Core tests passed
    set CORE_PASSED=1
) else (
    echo ❌ Core tests failed
    set CORE_PASSED=0
)

echo 🌐 Running E2E tests...
dart test test/e2e_test.dart
if %errorlevel% == 0 (
    echo ✅ E2E tests passed
    set E2E_PASSED=1
) else (
    echo ⚠️  E2E tests failed (may require network)
    set E2E_PASSED=0
)

echo ⚡ Running performance tests...
dart test test/performance_test.dart
if %errorlevel% == 0 (
    echo ✅ Performance tests passed
    set PERF_PASSED=1
) else (
    echo ⚠️  Performance tests failed (may be flaky)
    set PERF_PASSED=0
)

echo.
echo 📊 Test Summary:
echo ================
if %CORE_PASSED% == 1 (
    echo Core tests:        ✅ PASSED
) else (
    echo Core tests:        ❌ FAILED
)

if %E2E_PASSED% == 1 (
    echo E2E tests:         ✅ PASSED
) else (
    echo E2E tests:         ⚠️  SKIPPED/FAILED
)

if %PERF_PASSED% == 1 (
    echo Performance tests: ✅ PASSED
) else (
    echo Performance tests: ⚠️  SKIPPED/FAILED
)

echo.
if %CORE_PASSED% == 1 (
    echo 🎉 Core functionality is working correctly!
    if %E2E_PASSED% == 0 (
        echo 📝 Note: Some tests failed but core functionality is intact.
        echo    Performance and E2E tests can be flaky in some environments.
    )
    if %PERF_PASSED% == 0 (
        echo 📝 Note: Some tests failed but core functionality is intact.
        echo    Performance and E2E tests can be flaky in some environments.
    )
) else (
    echo 💥 Core tests failed - please fix before committing!
    exit /b 1
)
