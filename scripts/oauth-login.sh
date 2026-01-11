#!/bin/bash
# Hindsight Stack - OAuth Login Script
# =====================================
# Alternative to web UI for OAuth authorization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔐 Hindsight Stack - OAuth Login"
echo "================================"
echo ""
echo "This script helps you authorize OAuth providers for CLIProxyAPI."
echo "You can also use the web UI at http://localhost:8317/management.html"
echo ""

# Check if CLIProxyAPI is installed locally
if command -v cliproxyapi &> /dev/null; then
    CLI_CMD="cliproxyapi"
elif [ -f "/opt/homebrew/bin/cliproxyapi" ]; then
    CLI_CMD="/opt/homebrew/bin/cliproxyapi"
elif [ -f "/usr/local/bin/cliproxyapi" ]; then
    CLI_CMD="/usr/local/bin/cliproxyapi"
else
    echo "⚠️  CLIProxyAPI CLI not found locally."
    echo ""
    echo "Options:"
    echo "1. Install CLIProxyAPI locally:"
    echo "   brew tap router-for-me/cliproxyapi"
    echo "   brew install cliproxyapi"
    echo ""
    echo "2. Use Docker exec (tokens saved to volume):"
    echo "   docker exec -it cliproxyapi cliproxyapi --claude-login"
    echo ""
    echo "3. Use the web UI:"
    echo "   http://localhost:8317/management.html"
    echo ""

    read -p "Run OAuth login via Docker? [y/N] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CLI_CMD="docker exec -it cliproxyapi cliproxyapi"
    else
        exit 0
    fi
fi

echo "Select provider to authorize:"
echo ""
echo "1) Claude (Claude Code / Claude Max subscription)"
echo "2) Codex (ChatGPT / OpenAI Codex subscription)"
echo "3) Gemini (Google Gemini CLI subscription)"
echo "4) All providers"
echo "5) Exit"
echo ""

read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        echo ""
        echo "🔑 Authorizing Claude..."
        $CLI_CMD --claude-login
        ;;
    2)
        echo ""
        echo "🔑 Authorizing Codex..."
        $CLI_CMD --codex-login
        ;;
    3)
        echo ""
        echo "🔑 Authorizing Gemini..."
        $CLI_CMD --login
        ;;
    4)
        echo ""
        echo "🔑 Authorizing all providers..."
        echo ""
        echo "--- Claude ---"
        $CLI_CMD --claude-login || true
        echo ""
        echo "--- Codex ---"
        $CLI_CMD --codex-login || true
        echo ""
        echo "--- Gemini ---"
        $CLI_CMD --login || true
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ OAuth authorization complete!"
echo ""
echo "Check authorized accounts:"
echo "   http://localhost:8317/management.html → Auth Files"
