#!/usr/bin/env bash
# Test hook compatibility for project-scoped and global installs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPERPOWERS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================"
echo "Testing Hook Compatibility"
echo "========================================"
echo ""

# Test 1: Hook works without CLAUDE_PLUGIN_ROOT (global install fallback)
echo "Test 1: Global install (CLAUDE_PLUGIN_ROOT not set)..."
cd "$SUPERPOWERS_ROOT"
unset CLAUDE_PLUGIN_ROOT 2>/dev/null || true
output=$(timeout 5 ./hooks/session-start 2>&1)
if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then
    echo "  ✓ PASS: Produces valid JSON"
    # Verify it contains expected fields
    if echo "$output" | grep -q "additional_context"; then
        echo "  ✓ PASS: Contains additional_context field"
    else
        echo "  ✗ FAIL: Missing additional_context field"
        exit 1
    fi
    if echo "$output" | grep -q "hookSpecificOutput"; then
        echo "  ✓ PASS: Contains hookSpecificOutput field"
    else
        echo "  ✗ FAIL: Missing hookSpecificOutput field"
        exit 1
    fi
    if echo "$output" | grep -q "using-superpowers"; then
        echo "  ✓ PASS: Contains using-superpowers skill content"
    else
        echo "  ✗ FAIL: Missing skill content"
        exit 1
    fi
else
    echo "  ✗ FAIL: Invalid JSON output"
    exit 1
fi
echo ""

# Test 2: Hook works with CLAUDE_PLUGIN_ROOT set (project-scoped install)
echo "Test 2: Project-scoped install (CLAUDE_PLUGIN_ROOT set)..."
cd /tmp
export CLAUDE_PLUGIN_ROOT="$SUPERPOWERS_ROOT"
output=$(timeout 5 "$SUPERPOWERS_ROOT/hooks/session-start" 2>&1)
if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then
    echo "  ✓ PASS: Produces valid JSON"
    if echo "$output" | grep -q "additional_context"; then
        echo "  ✓ PASS: Contains additional_context field"
    else
        echo "  ✗ FAIL: Missing additional_context field"
        exit 1
    fi
    if echo "$output" | grep -q "using-superpowers"; then
        echo "  ✓ PASS: Contains using-superpowers skill content"
    else
        echo "  ✗ FAIL: Missing skill content"
        exit 1
    fi
else
    echo "  ✗ FAIL: Invalid JSON output"
    exit 1
fi
echo ""

# Test 3: Hook works with CLAUDE_PLUGIN_ROOT set to current dir
echo "Test 3: Project-scoped install (CLAUDE_PLUGIN_ROOT = .claude-plugin)..."
mkdir -p /tmp/test-project/.claude-plugin/hooks /tmp/test-project/.claude-plugin/skills/using-superpowers
cp "$SUPERPOWERS_ROOT/hooks/session-start" /tmp/test-project/.claude-plugin/hooks/
cp -r "$SUPERPOWERS_ROOT/skills/using-superpowers" /tmp/test-project/.claude-plugin/skills/
cd /tmp/test-project
export CLAUDE_PLUGIN_ROOT="$(pwd)/.claude-plugin"
output=$(timeout 5 "$CLAUDE_PLUGIN_ROOT/hooks/session-start" 2>&1)
if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then
    echo "  ✓ PASS: Produces valid JSON from project-scoped location"
    if echo "$output" | grep -q "using-superpowers"; then
        echo "  ✓ PASS: Loaded skill from project-scoped location"
    else
        echo "  ✗ FAIL: Could not load skill from project-scoped location"
        exit 1
    fi
else
    echo "  ✗ FAIL: Invalid JSON output"
    exit 1
fi
echo ""

# Cleanup
rm -rf /tmp/test-project

echo "========================================"
echo "All tests passed!"
echo "========================================"
