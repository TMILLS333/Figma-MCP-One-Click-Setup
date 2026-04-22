#!/usr/bin/env bash
# Figma MCP — One-Click Setup (macOS / Linux)
#
# Adds the official Figma MCP (https://mcp.figma.com/mcp, OAuth) to:
#   - Claude Desktop
#   - Claude Code
#   - VS Code
#
# Cowork uses a 2-click UI flow (Customize → Figma → Connect) and isn't
# scriptable, so it's documented in the README/landing page instead.
#
# Safe to re-run. Preserves any other MCPs already configured.

set -euo pipefail

# ---------- pretty output ----------
BOLD=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
RESET=$'\033[0m'

step()   { printf "\n${BOLD}${BLUE}▸${RESET} ${BOLD}%s${RESET}\n" "$*"; }
ok()     { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn()   { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
err()    { printf "  ${RED}✗${RESET} %s\n" "$*" >&2; }
prompt() { printf "${BOLD}%s${RESET} " "$*"; }

# ---------- detect OS ----------
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="mac"  ;;
  Linux)  PLATFORM="linux";;
  *) err "This script supports macOS and Linux. For Windows, use setup.ps1."; exit 1 ;;
esac

# ---------- config paths ----------
if [[ "$PLATFORM" == "mac" ]]; then
  CLAUDE_DESKTOP_DIR="$HOME/Library/Application Support/Claude"
  VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
  CLAUDE_DESKTOP_DIR="$HOME/.config/Claude"
  VSCODE_USER_DIR="$HOME/.config/Code/User"
fi
CLAUDE_DESKTOP_CONFIG="$CLAUDE_DESKTOP_DIR/claude_desktop_config.json"
VSCODE_MCP_CONFIG="$VSCODE_USER_DIR/mcp.json"

# ---------- Figma MCP endpoint ----------
FIGMA_MCP_URL="https://mcp.figma.com/mcp"

# ---------- banner ----------
clear 2>/dev/null || true
cat <<EOF

  ${RED}┌──┐${RESET}  ${MAGENTA}┌──┐${RESET}  ${BLUE}┌──┐${RESET}
  ${RED}│  │${RESET}  ${MAGENTA}│  │${RESET}  ${BLUE}│  │${RESET}     ${BOLD}Figma MCP — One-Click Setup${RESET}
  ${RED}└──┘${RESET}  ${MAGENTA}└──┘${RESET}  ${BLUE}└──┘${RESET}     ${DIM}design → AI${RESET}

  ${DIM}Safe to re-run.${RESET}

EOF

# ---------- which apps? ----------
# Cowork is handled separately (2-click UI flow documented in README + landing page),
# so it's not part of the scripted install.
step "Which apps do you want to set up?"
echo "  1) Claude Desktop"
echo "  2) Claude Code"
echo "  3) VS Code"
echo "  4) All — Claude Desktop, Claude Code, and VS Code"
echo
prompt "Pick [1-4, default 4]:"
# Read from /dev/tty so this works under `curl | bash` (where stdin is the pipe, not the terminal)
read -r choice </dev/tty || choice=""
choice="${choice:-4}"

DO_DESKTOP=0; DO_CODE=0; DO_VSCODE=0
case "$choice" in
  1) DO_DESKTOP=1 ;;
  2) DO_CODE=1 ;;
  3) DO_VSCODE=1 ;;
  4) DO_DESKTOP=1; DO_CODE=1; DO_VSCODE=1 ;;
  *) err "Invalid choice."; exit 1 ;;
esac

# ---------- preflight ----------
if [[ $DO_DESKTOP -eq 1 ]]; then
  step "Setting up Claude Desktop"
  if ! command -v node >/dev/null 2>&1; then
    err "Node.js is not installed. Claude Desktop needs it to connect to remote MCPs."
    if [[ "$PLATFORM" == "mac" ]]; then
      warn "Install it with: brew install node   (or download from https://nodejs.org)"
    else
      warn "Install Node from https://nodejs.org or via your package manager."
    fi
    warn "Skipping Claude Desktop. Re-run this script after installing Node."
    DO_DESKTOP=0
  fi
fi

if [[ $DO_DESKTOP -eq 1 || $DO_VSCODE -eq 1 ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    err "python3 is required for JSON merging but wasn't found."
    if [[ "$PLATFORM" == "mac" ]]; then
      warn "Install it with: xcode-select --install   (or brew install python3)"
    else
      warn "Install it with your package manager (e.g. sudo apt-get install python3)"
    fi
    exit 1
  fi
fi

# ---------- Claude Desktop ----------
if [[ $DO_DESKTOP -eq 1 ]]; then
  mkdir -p "$CLAUDE_DESKTOP_DIR"

  if [[ ! -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
    ok "Creating new config at $CLAUDE_DESKTOP_CONFIG"
    echo '{}' > "$CLAUDE_DESKTOP_CONFIG"
  else
    BACKUP="$CLAUDE_DESKTOP_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$CLAUDE_DESKTOP_CONFIG" "$BACKUP"
    ok "Backed up existing config to $(basename "$BACKUP")"
  fi

  python3 - "$CLAUDE_DESKTOP_CONFIG" "$FIGMA_MCP_URL" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
url  = sys.argv[2]
try:
    data = json.loads(path.read_text()) if path.read_text().strip() else {}
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
servers = data.setdefault("mcpServers", {})
servers["figma"] = {"command": "npx", "args": ["-y", "mcp-remote", url]}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  ok "Claude Desktop configured (existing servers preserved)."
fi

# ---------- Claude Code ----------
if [[ $DO_CODE -eq 1 ]]; then
  step "Setting up Claude Code"
  if ! command -v claude >/dev/null 2>&1; then
    warn "The 'claude' CLI is not installed. Install it from https://claude.com/claude-code and re-run."
  else
    if claude mcp list 2>/dev/null | grep -q "^figma\b\|^figma "; then
      ok "Claude Code already has 'figma' configured. Skipping."
    else
      if claude mcp add --transport http figma "$FIGMA_MCP_URL" --scope user 2>/dev/null; then
        ok "Added 'figma' to Claude Code (user scope)."
      else
        warn "Could not add via --transport http. Trying mcp-remote fallback..."
        if claude mcp add figma --scope user -- npx -y mcp-remote "$FIGMA_MCP_URL"; then
          ok "Added 'figma' via mcp-remote fallback."
        else
          err "Failed to add to Claude Code. Run manually:"
          echo "    claude mcp add --transport http figma $FIGMA_MCP_URL --scope user"
        fi
      fi
    fi
  fi
fi

# ---------- VS Code ----------
if [[ $DO_VSCODE -eq 1 ]]; then
  step "Setting up VS Code"
  mkdir -p "$VSCODE_USER_DIR"

  if [[ ! -f "$VSCODE_MCP_CONFIG" ]]; then
    ok "Creating new mcp.json at $VSCODE_MCP_CONFIG"
    echo '{}' > "$VSCODE_MCP_CONFIG"
  else
    BACKUP="$VSCODE_MCP_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$VSCODE_MCP_CONFIG" "$BACKUP"
    ok "Backed up existing VS Code mcp.json to $(basename "$BACKUP")"
  fi

  # VS Code uses "servers" (not "mcpServers") and takes a direct HTTP URL
  python3 - "$VSCODE_MCP_CONFIG" "$FIGMA_MCP_URL" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
url  = sys.argv[2]
try:
    data = json.loads(path.read_text()) if path.read_text().strip() else {}
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
data.setdefault("inputs", [])
servers = data.setdefault("servers", {})
servers["figma"] = {"url": url, "type": "http"}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  ok "VS Code configured."
  echo "    ${DIM}In VS Code, open mcp.json and click 'Start' above the figma server entry.${RESET}"
fi

# ---------- restart Claude Desktop so config loads ----------
if [[ $DO_DESKTOP -eq 1 && "$PLATFORM" == "mac" ]]; then
  step "Restart Claude Desktop so the new config loads"
  prompt "Restart Claude Desktop now? [Y/n]:"
  read -r a </dev/tty || a=""
  if [[ "${a:-y}" =~ ^[Yy] ]]; then
    osascript -e 'quit app "Claude"' 2>/dev/null || true
    sleep 2
    if [[ -d "/Applications/Claude.app" ]]; then
      open -a "Claude"
      ok "Claude restarted."
    else
      warn "Claude.app not found — open it manually."
    fi
  fi
fi

# ---------- done ----------
cat <<EOF

${BOLD}${GREEN}All set.${RESET}

${BOLD}Authenticate:${RESET} when you first use a Figma tool, a browser window
will open. Sign in to Figma and click ${BOLD}Allow${RESET}.

${BOLD}Test it:${RESET} in Claude, type  ${DIM}List MCP tools${RESET}
You should see Figma tools like ${CYAN}get_design_context${RESET}, ${CYAN}get_screenshot${RESET}, ${CYAN}get_metadata${RESET}.

EOF
