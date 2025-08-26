#!/bin/bash

# Test runner script for furl - runs all tests including performance tests
# Use this for local development and testing

echo "🧪 Running Furl Test Suite"
echo "=========================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📋 Running core tests...${NC}"
if dart test --exclude=test/performance_test.dart --exclude=test/e2e_test.dart; then
    echo -e "${GREEN}✅ Core tests passed${NC}"
    CORE_PASSED=true
else
    echo -e "${RED}❌ Core tests failed${NC}"
    CORE_PASSED=false
fi

echo -e "${YELLOW}🌐 Running E2E tests...${NC}"
if dart test test/e2e_test.dart; then
    echo -e "${GREEN}✅ E2E tests passed${NC}"
    E2E_PASSED=true
else
    echo -e "${YELLOW}⚠️  E2E tests failed (may require network)${NC}"
    E2E_PASSED=false
fi

echo -e "${YELLOW}⚡ Running performance tests...${NC}"
if dart test test/performance_test.dart; then
    echo -e "${GREEN}✅ Performance tests passed${NC}"
    PERF_PASSED=true
else
    echo -e "${YELLOW}⚠️  Performance tests failed (may be flaky)${NC}"
    PERF_PASSED=false
fi

echo ""
echo "📊 Test Summary:"
echo "================"
if [ "$CORE_PASSED" = true ]; then
    echo -e "Core tests:        ${GREEN}✅ PASSED${NC}"
else
    echo -e "Core tests:        ${RED}❌ FAILED${NC}"
fi

if [ "$E2E_PASSED" = true ]; then
    echo -e "E2E tests:         ${GREEN}✅ PASSED${NC}"
else
    echo -e "E2E tests:         ${YELLOW}⚠️  SKIPPED/FAILED${NC}"
fi

if [ "$PERF_PASSED" = true ]; then
    echo -e "Performance tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Performance tests: ${YELLOW}⚠️  SKIPPED/FAILED${NC}"
fi

echo ""
if [ "$CORE_PASSED" = true ]; then
    echo -e "${GREEN}🎉 Core functionality is working correctly!${NC}"
    if [ "$E2E_PASSED" = false ] || [ "$PERF_PASSED" = false ]; then
        echo -e "${YELLOW}📝 Note: Some tests failed but core functionality is intact.${NC}"
        echo -e "${YELLOW}   Performance and E2E tests can be flaky in some environments.${NC}"
    fi
else
    echo -e "${RED}💥 Core tests failed - please fix before committing!${NC}"
    exit 1
fi
