#!/usr/bin/env bash
# Figma MCP — One-Click Setup (macOS / Linux)
#
# Adds the official Figma MCP (https://mcp.figma.com/mcp, OAuth) to:
#   - Claude Desktop
#   - Claude Code
#   - Cowork (guided: Figma is an official connector in Cowork's registry)
#
# Safe to re-run. Preserves any other MCPs already configured.

set -euo pipefail

# ---------- pretty output ----------
BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'
YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
say()    { printf "%s\n" "$*"; }
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

# ---------- Claude Desktop config path ----------
if [[ "$PLATFORM" == "mac" ]]; then
  CLAUDE_DESKTOP_DIR="$HOME/Library/Application Support/Claude"
else
  CLAUDE_DESKTOP_DIR="$HOME/.config/Claude"
fi
CLAUDE_DESKTOP_CONFIG="$CLAUDE_DESKTOP_DIR/claude_desktop_config.json"

# ---------- the Figma MCP entry (remote, OAuth via mcp-remote) ----------
FIGMA_MCP_URL="https://mcp.figma.com/mcp"
FIGMA_ENTRY_JSON='{
  "command": "npx",
  "args": ["-y", "mcp-remote", "'"$FIGMA_MCP_URL"'"]
}'

# ---------- header ----------
clear 2>/dev/null || true
cat <<EOF
${BOLD}Figma MCP — One-Click Setup${RESET}
${DIM}Connects Figma to Claude Desktop, Claude Code, and Cowork.${RESET}

EOF

# ---------- which clients? ----------
step "Which clients do you want to set up?"
echo "  1) All three — Claude Desktop, Claude Code, and Cowork (recommended)"
echo "  2) Claude Desktop only"
echo "  3) Claude Code only"
echo "  4) Cowork only (just show me the two clicks)"
echo "  5) Custom — pick a combo"
echo
prompt "Pick [1-5, default 1]:"
read -r choice
choice="${choice:-1}"

DO_DESKTOP=0; DO_CODE=0; DO_COWORK=0
case "$choice" in
  1) DO_DESKTOP=1; DO_CODE=1; DO_COWORK=1 ;;
  2) DO_DESKTOP=1 ;;
  3) DO_CODE=1 ;;
  4) DO_COWORK=1 ;;
  5)
    prompt "Claude Desktop? [Y/n]:"; read -r a; [[ "${a:-y}" =~ ^[Yy] ]] && DO_DESKTOP=1
    prompt "Claude Code? [Y/n]:";    read -r a; [[ "${a:-y}" =~ ^[Yy] ]] && DO_CODE=1
    prompt "Cowork? [Y/n]:";         read -r a; [[ "${a:-y}" =~ ^[Yy] ]] && DO_COWORK=1
    ;;
  *) err "Invalid choice."; exit 1 ;;
esac

# ---------- Claude Desktop ----------
if [[ $DO_DESKTOP -eq 1 ]]; then
  step "Setting up Claude Desktop"

  # Node check — needed for npx mcp-remote
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

if [[ $DO_DESKTOP -eq 1 ]]; then
  mkdir -p "$CLAUDE_DESKTOP_DIR"

  if [[ ! -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
    ok "Creating new config at $CLAUDE_DESKTOP_CONFIG"
    echo '{}' > "$CLAUDE_DESKTOP_CONFIG"
  else
    # back up existing config
    BACKUP="$CLAUDE_DESKTOP_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$CLAUDE_DESKTOP_CONFIG" "$BACKUP"
    ok "Backed up existing config to $(basename "$BACKUP")"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    err "python3 is required for JSON merging but wasn't found."
    if [[ "$PLATFORM" == "mac" ]]; then
      warn "Install it with: brew install python3"
    fi
    exit 1
  fi

  python3 - "$CLAUDE_DESKTOP_CONFIG" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text()) if path.read_text().strip() else {}
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
servers = data.setdefault("mcpServers", {})
servers["figma"] = {
    "command": "npx",
    "args": ["-y", "mcp-remote", "https://mcp.figma.com/mcp"]
}
path.write_text(json.dumps(data, indent=2) + "\n")
print("  \033[32m\u2713\033[0m Added 'figma' to mcpServers (existing servers preserved)")
PY

  ok "Claude Desktop configured."
fi

# ---------- Claude Code ----------
if [[ $DO_CODE -eq 1 ]]; then
  step "Setting up Claude Code"
  if ! command -v claude >/dev/null 2>&1; then
    warn "The 'claude' CLI is not installed. Install it from https://claude.com/claude-code and re-run."
  else
    # Check if already present
    if claude mcp list 2>/dev/null | grep -q "^figma\b\|^figma "; then
      ok "Claude Code already has 'figma' configured. Skipping."
    else
      if claude mcp add --transport http figma "$FIGMA_MCP_URL" --scope user 2>/dev/null; then
        ok "Added 'figma' to Claude Code (user scope)."
      else
        warn "Could not add via --transport http. Trying fallback with mcp-remote..."
        if claude mcp add figma -- npx -y mcp-remote "$FIGMA_MCP_URL" --scope user; then
          ok "Added 'figma' via mcp-remote fallback."
        else
          err "Failed to add to Claude Code. Run manually:"
          echo "    claude mcp add --transport http figma $FIGMA_MCP_URL --scope user"
        fi
      fi
    fi
  fi
fi

# ---------- Cowork (guided — 2 clicks) ----------
if [[ $DO_COWORK -eq 1 ]]; then
  step "Setting up Cowork"
  cat <<EOF
  Figma is an official Cowork connector — this part is 2 clicks, no file editing.

  ${BOLD}In Claude:${RESET}
    1. Open Claude Desktop and click the ${BOLD}Cowork${RESET} tab.
    2. Click ${BOLD}Customize${RESET} in the left sidebar.
    3. Click ${BOLD}Browse connectors${RESET} (or Browse plugins).
    4. Find ${BOLD}Figma${RESET} in the list and click ${BOLD}Connect${RESET}.
    5. Sign in to Figma, click ${BOLD}Allow${RESET}. Done.

EOF
  if [[ "$PLATFORM" == "mac" ]]; then
    prompt "Open Claude now? [Y/n]:"
    read -r a
    if [[ "${a:-y}" =~ ^[Yy] ]]; then
      if [[ -d "/Applications/Claude.app" ]]; then
        open -a "Claude"
        ok "Claude launched. Click the Cowork tab → Customize → Figma → Connect."
      else
        warn "Claude.app not found in /Applications. Open it manually."
      fi
    fi
  fi
fi

# ---------- restart Claude Desktop so config loads ----------
if [[ $DO_DESKTOP -eq 1 && "$PLATFORM" == "mac" ]]; then
  step "Restart Claude Desktop so the new config loads"
  prompt "Restart Claude Desktop now? [Y/n]:"
  read -r a
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

${BOLD}Test it:${RESET} in Claude, type  ${DIM}List MCP tools${RESET}
You should see Figma tools like get_design_context, get_screenshot, get_metadata.

${DIM}Part of How to Platypus · weareplatypus.com${RESET}
EOF
