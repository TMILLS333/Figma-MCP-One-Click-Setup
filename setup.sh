#!/bin/bash

# ─────────────────────────────────────────────────────────────
# Figma MCP — One-Click Setup
# Configures the remote (mcp.figma.com) or desktop (local) server
# Usage: ./setup.sh
#        ./setup.sh --force
# ─────────────────────────────────────────────────────────────

set -e

# Parse flags
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
    esac
done

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Server URLs
REMOTE_URL="https://mcp.figma.com/mcp"
DESKTOP_URL="http://127.0.0.1:3845/mcp"

# Config file paths
if [ "$(uname)" = "Darwin" ]; then
    CLAUDE_CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    VSCODE_USER_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
else
    CLAUDE_CONFIG_FILE="$HOME/.config/Claude/claude_desktop_config.json"
    VSCODE_USER_CONFIG_DIR="$HOME/.config/Code/User"
fi
CURSOR_CONFIG_FILE="$HOME/.cursor/mcp.json"
CLAUDE_CODE_CONFIG_FILE="$HOME/.claude.json"
VSCODE_MCP_CONFIG="$VSCODE_USER_CONFIG_DIR/mcp.json"
CONFIG_FILES=("$CLAUDE_CONFIG_FILE" "$CURSOR_CONFIG_FILE" "$CLAUDE_CODE_CONFIG_FILE")

# State
SERVER_NAME=""
SERVER_URL=""
SERVER_TYPE=""

# ─────────────────────────────────────────────────────────────
# JSON helpers (python3 — pre-installed on macOS & most Linux)
# ─────────────────────────────────────────────────────────────

has_figma_config() {
    local config_path="$1"
    if [ ! -f "$config_path" ]; then return 1; fi
    grep -qE '"figma"|"figma-desktop"' "$config_path" 2>/dev/null
}

get_server_name() {
    local config_path="$1"
    if [ ! -f "$config_path" ]; then echo ""; return; fi
    if grep -q '"figma-desktop"' "$config_path" 2>/dev/null; then
        echo "figma-desktop"
    elif grep -q '"figma"' "$config_path" 2>/dev/null; then
        echo "figma"
    else
        echo ""
    fi
}

get_configured_clients() {
    local clients=""
    for cf in "${CONFIG_FILES[@]}"; do
        if has_figma_config "$cf"; then
            local label=""
            if [ "$cf" = "$CLAUDE_CONFIG_FILE" ]; then label="Claude Desktop"; fi
            if [ "$cf" = "$CLAUDE_CODE_CONFIG_FILE" ]; then label="Claude Code"; fi
            if [ "$cf" = "$CURSOR_CONFIG_FILE" ]; then label="Cursor"; fi
            [ -n "$clients" ] && clients="$clients, "
            clients="$clients$label"
        fi
    done
    if has_figma_config "$VSCODE_MCP_CONFIG"; then
        [ -n "$clients" ] && clients="$clients, "
        clients="${clients}VS Code"
    fi
    echo "$clients"
}

detect_current_mode() {
    for cf in "${CONFIG_FILES[@]}" "$VSCODE_MCP_CONFIG"; do
        local name=$(get_server_name "$cf")
        if [ "$name" = "figma-desktop" ]; then echo "desktop"; return; fi
        if [ "$name" = "figma" ]; then echo "remote"; return; fi
    done
    echo ""
}

# Write/merge mcpServers config (Claude Desktop, Cursor, Claude Code)
write_mcp_servers_config() {
    local CONFIG_FILE="$1"
    local LABEL="$2"
    local NAME="$3"
    local URL="$4"

    mkdir -p "$(dirname "$CONFIG_FILE")"

    if ! python3 -c "
import json, sys, os
config_path, name, url = sys.argv[1], sys.argv[2], sys.argv[3]
config = {}
if os.path.isfile(config_path):
    with open(config_path) as f:
        config = json.load(f)
servers = config.setdefault('mcpServers', {})
servers.pop('figma', None)
servers.pop('figma-desktop', None)
servers[name] = {'url': url}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
" "$CONFIG_FILE" "$NAME" "$URL" 2>/dev/null; then
        echo -e "${RED}   ❌ $CONFIG_FILE has invalid JSON — fix it manually${NC}"
        return 1
    fi
    echo -e "${GREEN}   ✅ $LABEL configured${NC}"
}

# Write VS Code mcp.json (servers format, not mcpServers)
write_vscode_config() {
    local NAME="$1"
    local URL="$2"

    mkdir -p "$VSCODE_USER_CONFIG_DIR"

    if ! python3 -c "
import json, sys, os
config_path, name, url = sys.argv[1], sys.argv[2], sys.argv[3]
config = {}
if os.path.isfile(config_path):
    with open(config_path) as f:
        config = json.load(f)
config.setdefault('inputs', [])
servers = config.setdefault('servers', {})
servers.pop('figma', None)
servers.pop('figma-desktop', None)
servers[name] = {'url': url, 'type': 'http'}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
" "$VSCODE_MCP_CONFIG" "$NAME" "$URL" 2>/dev/null; then
        echo -e "${RED}   ❌ $VSCODE_MCP_CONFIG has invalid JSON — fix it manually${NC}"
        return 1
    fi
    echo -e "${GREEN}   ✅ VS Code configured${NC}"
}

# Configure Claude Code via CLI
configure_claude_code() {
    local NAME="$1"
    local URL="$2"

    if command -v claude &> /dev/null; then
        claude mcp remove figma --scope user 2>/dev/null || true
        claude mcp remove figma-desktop --scope user 2>/dev/null || true
        if claude mcp add --transport http --scope user "$NAME" "$URL"; then
            echo -e "${GREEN}   ✅ Claude Code configured (via CLI)${NC}"
            return 0
        fi
        echo -e "${YELLOW}   ⚠️  'claude mcp add' failed — writing config directly${NC}"
    fi
    write_mcp_servers_config "$CLAUDE_CODE_CONFIG_FILE" "Claude Code" "$NAME" "$URL"
}

# Client configurators
configure_desktop_app() { write_mcp_servers_config "$CLAUDE_CONFIG_FILE" "Claude Desktop" "$SERVER_NAME" "$SERVER_URL"; }
configure_cursor()      { write_mcp_servers_config "$CURSOR_CONFIG_FILE" "Cursor" "$SERVER_NAME" "$SERVER_URL"; }
configure_vscode()      { write_vscode_config "$SERVER_NAME" "$SERVER_URL"; }
configure_code()        { configure_claude_code "$SERVER_NAME" "$SERVER_URL"; }

# Prompt for client selection
update_client_configs() {
    echo "   1) Claude Desktop"
    echo "   2) Claude Code"
    echo "   3) Cursor"
    echo "   4) VS Code"
    echo "   5) All of the above"
    echo "   6) Skip"
    echo ""
    read -p "   Enter 1-6: " CC
    echo ""
    case "$CC" in
        1) configure_desktop_app ;;
        2) configure_code ;;
        3) configure_cursor ;;
        4) configure_vscode ;;
        5) configure_desktop_app || true; configure_code || true; configure_cursor || true; configure_vscode || true ;;
        6) echo -e "${YELLOW}   Skipped${NC}" ;;
        *) echo -e "${YELLOW}   Skipped${NC}" ;;
    esac
}

# Restart Claude Desktop if running (macOS)
restart_claude() {
    if [ "$(uname)" = "Darwin" ] && pgrep -x "Claude" > /dev/null 2>&1; then
        echo -e "   ${DIM}Restarting Claude Desktop...${NC}"
        osascript -e 'quit app "Claude"' 2>/dev/null || true
        sleep 2
        open -a "Claude" 2>/dev/null && echo -e "${GREEN}   ✅ Claude Desktop restarted${NC}" || \
            echo -e "${YELLOW}   ⚠️  Claude Desktop stopped — please reopen it manually${NC}"
    fi
}

# ─────────────────────────────────────────────────────────────
# Preflight: python3
# ─────────────────────────────────────────────────────────────
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ python3 not found${NC}"
    echo ""
    echo "   Install Python 3:"
    echo "   • macOS:  xcode-select --install  (or brew install python3)"
    echo "   • Ubuntu: sudo apt-get install python3"
    echo ""
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}   Figma MCP — One-Click Setup                        ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}   Remote  •  Desktop                                 ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}${CYAN}          *        .    *      *              ${NC}${BOLD}║${NC}"
printf "${BOLD}║${NC}${CYAN}    *    /|\\\\    *    /|\\\\   .  /|\\\\             ${NC}${BOLD}║${NC}\n"
printf "${BOLD}║${NC}${CYAN}  .  @  / | \\\\     / | \\\\  @/ | \\\\   *         ${NC}${BOLD}║${NC}\n"
printf "${BOLD}║${NC}${CYAN}    /#\\\\  \\\\___/  .  \\\\___/ /#\\\\ ___/           ${NC}${BOLD}║${NC}\n"
printf "${BOLD}║${NC}${GREEN}  __|||___||______||___|||__||________      ${NC}${BOLD}║${NC}\n"
echo -e "${BOLD}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  Connects your AI coding tool to Figma so it can    ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  read designs, generate code, and stay in sync.     ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  Supports: Claude Desktop, Claude Code, Cursor,     ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  and VS Code. No API tokens needed — uses OAuth.    ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}   Why use this?${NC}"
echo -e "   ${DIM}• Without this, you'd manually edit JSON config files${NC}"
echo -e "   ${DIM}• Each AI client stores MCP settings in a different place${NC}"
echo -e "   ${DIM}• This script finds the right file, merges the entry,${NC}"
echo -e "   ${DIM}  and preserves your existing settings — in seconds.${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# Smart re-run detection
# ─────────────────────────────────────────────────────────────
if [ "$FORCE" = false ]; then
    CURRENT_MODE=$(detect_current_mode)
    CONFIGURED_CLIENTS=$(get_configured_clients)

    if [ -n "$CURRENT_MODE" ] && [ -n "$CONFIGURED_CLIENTS" ]; then
        echo -e "${GREEN}   Setup is already complete!${NC}"
        echo ""
        echo -e "   ${BOLD}Current settings:${NC}"
        echo -e "   ${DIM}  Mode:     $CURRENT_MODE${NC}"
        echo -e "   ${DIM}  Clients:  $CONFIGURED_CLIENTS${NC}"
        echo ""
        echo -e "   ${BOLD}What would you like to do?${NC}"
        echo "    1) Switch mode (remote ↔ desktop)"
        echo "    2) Add/change client (Claude Desktop / Claude Code / Cursor / VS Code)"
        echo "    3) Full re-setup (same as --force)"
        echo "    4) Exit — nothing to change"
        echo ""
        read -p "   Choose [1-4]: " RERUN_CHOICE

        case "$RERUN_CHOICE" in
            1)
                echo ""
                echo -e "   ${CYAN}Switch Server Mode${NC}"
                echo ""
                if [ "$CURRENT_MODE" = "remote" ]; then
                    echo -e "   Currently using ${BOLD}remote${NC} server. Switch to ${BOLD}desktop${NC}?"
                    read -p "   (Y/n): " SWITCH
                    if [ "$SWITCH" = "n" ] || [ "$SWITCH" = "N" ]; then
                        echo -e "${YELLOW}   Cancelled.${NC}"; exit 0
                    fi
                    SERVER_NAME="figma-desktop"
                    SERVER_URL="$DESKTOP_URL"
                    SERVER_TYPE="desktop"
                else
                    echo -e "   Currently using ${BOLD}desktop${NC} server. Switch to ${BOLD}remote${NC}?"
                    read -p "   (Y/n): " SWITCH
                    if [ "$SWITCH" = "n" ] || [ "$SWITCH" = "N" ]; then
                        echo -e "${YELLOW}   Cancelled.${NC}"; exit 0
                    fi
                    SERVER_NAME="figma"
                    SERVER_URL="$REMOTE_URL"
                    SERVER_TYPE="remote"
                fi
                for cf in "${CONFIG_FILES[@]}"; do
                    if has_figma_config "$cf"; then
                        if [ "$cf" = "$CLAUDE_CODE_CONFIG_FILE" ]; then
                            configure_code; continue
                        fi
                        label=""
                        if [ "$cf" = "$CLAUDE_CONFIG_FILE" ]; then label="Claude Desktop"; fi
                        if [ "$cf" = "$CURSOR_CONFIG_FILE" ]; then label="Cursor"; fi
                        write_mcp_servers_config "$cf" "$label" "$SERVER_NAME" "$SERVER_URL"
                    fi
                done
                if has_figma_config "$VSCODE_MCP_CONFIG"; then
                    configure_vscode
                fi
                restart_claude
                echo ""
                echo -e "${GREEN}   ✅ Switched to $SERVER_TYPE mode!${NC}"
                if [ "$SERVER_TYPE" = "desktop" ]; then
                    echo ""
                    echo -e "   ${YELLOW}Remember:${NC} Open Figma Desktop → Dev Mode → Enable desktop MCP server"
                fi
                exit 0
                ;;
            2)
                echo ""
                echo -e "   ${CYAN}Add/Change Client${NC}"
                echo ""
                if [ "$CURRENT_MODE" = "remote" ]; then
                    SERVER_NAME="figma"; SERVER_URL="$REMOTE_URL"; SERVER_TYPE="remote"
                else
                    SERVER_NAME="figma-desktop"; SERVER_URL="$DESKTOP_URL"; SERVER_TYPE="desktop"
                fi
                update_client_configs
                restart_claude
                echo ""
                echo -e "${GREEN}   ✅ Client config updated!${NC}"
                exit 0
                ;;
            3)
                echo ""
                echo -e "   ${CYAN}Running full setup...${NC}"
                echo ""
                ;;
            *)
                echo ""
                echo -e "${GREEN}   No changes. Bye!${NC}"
                exit 0
                ;;
        esac
    fi
fi

# ─────────────────────────────────────────────────────────────
# Step 1: Choose server mode
# ─────────────────────────────────────────────────────────────
echo -e "${BOLD}Step 1/2 — Choose server mode${NC}"
echo ""
echo -e "   ${CYAN}1)${NC} ${BOLD}Remote${NC}   — mcp.figma.com (OAuth, no desktop app needed)"
echo -e "             ${DIM}Supports: code generation, design context, send UI to Figma${NC}"
echo -e "             ${DIM}Works anywhere — just authenticate in browser${NC}"
echo ""
echo -e "   ${CYAN}2)${NC} ${BOLD}Desktop${NC}  — Figma Desktop app (local server on port 3845)"
echo -e "             ${DIM}Supports: code generation, design context, selection-based prompts${NC}"
echo -e "             ${DIM}Requires Figma Desktop with Dev Mode enabled${NC}"
echo ""
read -p "   Choose [1-2] (default: 1): " MODE_CHOICE

case "$MODE_CHOICE" in
    2)
        SERVER_NAME="figma-desktop"
        SERVER_URL="$DESKTOP_URL"
        SERVER_TYPE="desktop"
        echo ""
        echo -e "${GREEN}   ✅ Desktop mode selected${NC}"
        echo ""
        echo -e "   ${YELLOW}Important:${NC} Before using the MCP server, you must:"
        echo -e "   ${CYAN}1.${NC} Open the ${BOLD}Figma Desktop app${NC} (latest version)"
        echo -e "   ${CYAN}2.${NC} Open a Figma Design file"
        echo -e "   ${CYAN}3.${NC} Toggle to ${BOLD}Dev Mode${NC} (⇧D)"
        echo -e "   ${CYAN}4.${NC} Click ${BOLD}Enable desktop MCP server${NC} in the inspect panel"
        echo ""
        echo -e "   ${DIM}The server runs at http://127.0.0.1:3845/mcp${NC}"
        ;;
    *)
        SERVER_NAME="figma"
        SERVER_URL="$REMOTE_URL"
        SERVER_TYPE="remote"
        echo ""
        echo -e "${GREEN}   ✅ Remote mode selected${NC}"
        echo -e "   ${DIM}You'll authenticate via browser when first connecting${NC}"
        ;;
esac

echo ""

# ─────────────────────────────────────────────────────────────
# Step 2: Configure client(s)
# ─────────────────────────────────────────────────────────────
echo -e "${BOLD}Step 2/2 — Configure your AI client${NC}"
echo ""
echo "   Which client do you use?"
update_client_configs

echo ""

# ─────────────────────────────────────────────────────────────
# Authentication instructions
# ─────────────────────────────────────────────────────────────
if [ "$SERVER_TYPE" = "remote" ]; then
    echo -e "${BOLD}Next: Authenticate${NC}"
    echo ""
    echo -e "   When you first use the Figma MCP server in your client,"
    echo -e "   you'll be prompted to authenticate via your browser."
    echo ""
    echo -e "   ${CYAN}For Claude Code:${NC}"
    echo -e "     Type ${BOLD}/mcp${NC} → select ${BOLD}figma${NC} → ${BOLD}Authenticate${NC}"
    echo -e "     Click ${BOLD}Allow Access${NC} in the browser"
    echo ""
    echo -e "   ${CYAN}For Cursor:${NC}"
    echo -e "     Click ${BOLD}Connect${NC} next to Figma in MCP settings"
    echo -e "     Click ${BOLD}Allow Access${NC} in the browser"
    echo ""
    echo -e "   ${CYAN}For VS Code:${NC}"
    echo -e "     Click ${BOLD}Start${NC} above the server name in mcp.json"
    echo -e "     Click ${BOLD}Allow Access${NC} in the browser"
    echo ""
fi

# ─── Done ───────────────────────────────────────────────────
restart_claude

echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "   ${BOLD}${GREEN}🎉 Setup complete!${NC}"
echo ""
if [ "$SERVER_TYPE" = "remote" ]; then
    echo -e "   ${BOLD}To verify, try prompting:${NC}"
    echo -e "   ${DIM}\"Get the design context from <paste a Figma link>\"${NC}"
elif [ "$SERVER_TYPE" = "desktop" ]; then
    echo -e "   ${BOLD}Make sure Figma Desktop is running with Dev Mode enabled,${NC}"
    echo -e "   ${BOLD}then try prompting:${NC}"
    echo -e "   ${DIM}\"Implement my current selection\"${NC}"
fi
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
