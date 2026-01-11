#!/bin/bash
# Hindsight Stack - Stop Script
# =============================
# Stops all components gracefully

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLIPROXYAPI_PID="$HOME/.cli-proxy-api/server.pid"
PROXY_DIR="$PROJECT_DIR/markdown-proxy"
PROXY_PID="$PROXY_DIR/proxy.pid"

cd "$PROJECT_DIR"

echo "🛑 Stopping Hindsight Stack..."
echo ""

# ============================================
# 1. Stop Hindsight (Docker)
# ============================================
echo "📦 Stopping Hindsight container..."
docker compose down 2>/dev/null || true
echo "   ✅ Hindsight stopped"

# ============================================
# 2. Stop Markdown Proxy
# ============================================
echo ""
echo "🔧 Stopping Markdown Proxy..."
if [ -f "$PROXY_PID" ]; then
    PID=$(cat "$PROXY_PID")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        echo "   ✅ Stopped Markdown Proxy (PID: $PID)"
    else
        echo "   ⚠️  Markdown Proxy was not running"
    fi
    rm -f "$PROXY_PID"
else
    # Try to find and kill by port
    lsof -i :8318 2>/dev/null | grep LISTEN | awk '{print $2}' | xargs kill 2>/dev/null || true
    echo "   ✅ Markdown Proxy stopped"
fi

# ============================================
# 3. Stop CLIProxyAPI (optional)
# ============================================
echo ""
echo "🔌 Stopping CLIProxyAPI..."

# Ask user if they want to stop CLIProxyAPI
if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
    if [ -f "$CLIPROXYAPI_PID" ]; then
        PID=$(cat "$CLIPROXYAPI_PID")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
            echo "   ✅ Stopped CLIProxyAPI (PID: $PID)"
        fi
        rm -f "$CLIPROXYAPI_PID"
    else
        lsof -i :8317 2>/dev/null | grep LISTEN | awk '{print $2}' | xargs kill 2>/dev/null || true
        echo "   ✅ CLIProxyAPI stopped"
    fi
else
    echo "   ⏭️  CLIProxyAPI kept running (use --all to stop)"
fi

# ============================================
# Status
# ============================================
echo ""
echo "✅ Hindsight Stack stopped."
echo ""
echo "💾 Data preserved:"
echo "   OAuth tokens:  ~/.cli-proxy-api/"
echo "   Memory data:   ./data/pg0/"
echo ""
echo "🗑️  To remove all data:"
echo "   docker compose down -v"
echo "   rm -rf ./data/pg0/"
