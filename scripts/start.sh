#!/bin/bash
# Hindsight Stack - Start Script
# ==============================
# Starts all components: CLIProxyAPI → Markdown Proxy → Hindsight

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLIPROXYAPI_BIN="$HOME/bin/cliproxyapi"
CLIPROXYAPI_CONFIG="$HOME/.cli-proxy-api/config.yaml"
CLIPROXYAPI_PID="$HOME/.cli-proxy-api/server.pid"
CLIPROXYAPI_LOG="$HOME/.cli-proxy-api/server.log"
PROXY_DIR="$PROJECT_DIR/markdown-proxy"
PROXY_PID="$PROXY_DIR/proxy.pid"
PROXY_LOG="$PROXY_DIR/proxy.log"

cd "$PROJECT_DIR"

echo "🚀 Starting Hindsight Stack..."
echo ""

# Load environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# ============================================
# 1. Start CLIProxyAPI (OAuth proxy)
# ============================================
echo "🔌 Starting CLIProxyAPI..."

# Check if already running
if [ -f "$CLIPROXYAPI_PID" ]; then
    OLD_PID=$(cat "$CLIPROXYAPI_PID")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "   ✅ CLIProxyAPI already running (PID: $OLD_PID)"
    else
        rm -f "$CLIPROXYAPI_PID"
    fi
fi

# Start if not running
if [ ! -f "$CLIPROXYAPI_PID" ] || ! kill -0 "$(cat "$CLIPROXYAPI_PID" 2>/dev/null)" 2>/dev/null; then
    if [ -f "$CLIPROXYAPI_BIN" ]; then
        "$CLIPROXYAPI_BIN" -config "$CLIPROXYAPI_CONFIG" > "$CLIPROXYAPI_LOG" 2>&1 &
        echo $! > "$CLIPROXYAPI_PID"
        echo "   ✅ Started CLIProxyAPI (PID: $(cat $CLIPROXYAPI_PID))"
        sleep 2
    else
        echo "   ❌ CLIProxyAPI binary not found at $CLIPROXYAPI_BIN"
        echo "   Download from: https://github.com/router-for-me/CLIProxyAPI/releases"
        exit 1
    fi
fi

# Check CLIProxyAPI is responding
if curl -s http://localhost:8317/v1/models > /dev/null 2>&1; then
    echo "   ✅ CLIProxyAPI responding on :8317"
else
    echo "   ⚠️  CLIProxyAPI not responding (may need OAuth login)"
    echo "   Run: ~/bin/cliproxyapi -config ~/.cli-proxy-api/config.yaml -claude-login"
fi

# ============================================
# 2. Start Markdown Proxy
# ============================================
echo ""
echo "🔧 Starting Markdown Proxy..."

# Kill old proxy if exists
if [ -f "$PROXY_PID" ]; then
    OLD_PID=$(cat "$PROXY_PID")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "   ✅ Markdown Proxy already running (PID: $OLD_PID)"
    else
        rm -f "$PROXY_PID"
    fi
fi

# Start if not running
if [ ! -f "$PROXY_PID" ] || ! kill -0 "$(cat "$PROXY_PID" 2>/dev/null)" 2>/dev/null; then
    if [ -d "$PROXY_DIR" ]; then
        # Ensure venv exists
        if [ ! -d "$PROXY_DIR/.venv" ]; then
            echo "   Setting up virtual environment..."
            python3 -m venv "$PROXY_DIR/.venv"
            "$PROXY_DIR/.venv/bin/pip" install -q -r "$PROXY_DIR/requirements.txt"
        fi

        cd "$PROXY_DIR"
        .venv/bin/python main.py > "$PROXY_LOG" 2>&1 &
        echo $! > "$PROXY_PID"
        cd "$PROJECT_DIR"
        echo "   ✅ Started Markdown Proxy (PID: $(cat $PROXY_PID))"
        sleep 2
    else
        echo "   ❌ Markdown Proxy directory not found"
        exit 1
    fi
fi

# Check proxy is responding
if curl -s http://localhost:8318/health > /dev/null 2>&1; then
    echo "   ✅ Markdown Proxy responding on :8318"
else
    echo "   ❌ Markdown Proxy failed to start"
    cat "$PROXY_LOG"
    exit 1
fi

# ============================================
# 3. Start Hindsight (Docker)
# ============================================
echo ""
echo "📦 Starting Hindsight container..."
docker compose up -d

# Wait for Hindsight to be healthy
echo ""
echo "⏳ Waiting for Hindsight to start..."
for i in {1..30}; do
    if curl -s http://localhost:8888/health > /dev/null 2>&1; then
        break
    fi
    sleep 2
done

# ============================================
# Status Check
# ============================================
echo ""
echo "📊 Service Status:"
echo "────────────────────────────────────────"

# CLIProxyAPI
if curl -s http://localhost:8317/v1/models > /dev/null 2>&1; then
    echo "   CLIProxyAPI:     ✅ :8317"
else
    echo "   CLIProxyAPI:     ❌ not responding"
fi

# Markdown Proxy
if curl -s http://localhost:8318/health > /dev/null 2>&1; then
    echo "   Markdown Proxy:  ✅ :8318"
else
    echo "   Markdown Proxy:  ❌ not responding"
fi

# Hindsight
HEALTH=$(curl -s http://localhost:8888/health 2>/dev/null)
if [ -n "$HEALTH" ]; then
    echo "   Hindsight API:   ✅ :8888"
    echo "   Hindsight UI:    ✅ :9999"
else
    echo "   Hindsight:       ❌ not responding"
fi

echo "────────────────────────────────────────"
echo ""
echo "✅ Hindsight Stack started!"
echo ""
echo "🔗 Endpoints:"
echo "   Hindsight API:     http://localhost:8888"
echo "   Hindsight UI:      http://localhost:9999"
echo "   Management:        http://localhost:8317/management.html"
echo ""
echo "🧪 Test memory:"
echo '   curl -X POST http://localhost:8888/v1/default/banks/test/memories \'
echo '     -H "Content-Type: application/json" \'
echo '     -d '\''{"items": [{"content": "Hello, Hindsight!"}], "async": false}'\'''
