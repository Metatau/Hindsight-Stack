#!/bin/bash
# Hindsight Stack - Status Script
# ===============================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "📊 Hindsight Stack Status"
echo "========================="
echo ""

# Docker status
echo "🐳 Docker Containers:"
docker compose ps
echo ""

# Health checks
echo "🏥 Health Checks:"
echo ""

# CLIProxyAPI
echo -n "   CLIProxyAPI (8317): "
if curl -s http://localhost:8317/v1/models > /dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Not responding"
fi

# Markdown Proxy
echo -n "   Markdown Proxy (8318): "
if curl -s http://localhost:8318/health > /dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Not responding"
fi

# Hindsight
echo -n "   Hindsight (8888):   "
if curl -s -f http://localhost:8888/health > /dev/null 2>&1; then
    echo "✅ Healthy"
else
    echo "❌ Not responding"
fi

echo ""

# Available models
echo "🤖 Available Models (via CLIProxyAPI):"
MODELS=$(curl -s http://localhost:8317/v1/models 2>/dev/null)
if [ -n "$MODELS" ]; then
    echo "$MODELS" | jq -r '.data[].id' 2>/dev/null | head -10 | sed 's/^/   - /'
else
    echo "   ⚠️  Could not fetch models (CLIProxyAPI may not be ready)"
fi

echo ""

# Memory stats
echo "🧠 Memory Bank Stats:"
STATS=$(curl -s -X POST http://localhost:8888/stats \
    -H "Content-Type: application/json" \
    -d '{"bank_id": "claude-code-memory"}' 2>/dev/null)
if [ -n "$STATS" ]; then
    echo "$STATS" | jq . 2>/dev/null || echo "   $STATS"
else
    echo "   ⚠️  Could not fetch stats (Hindsight may not be ready)"
fi

echo ""
echo "🔗 Endpoints:"
echo "   - Hindsight API:     http://localhost:8888"
echo "   - CLIProxyAPI:       http://localhost:8317"
echo "   - Management UI:     http://localhost:8317/management.html"
