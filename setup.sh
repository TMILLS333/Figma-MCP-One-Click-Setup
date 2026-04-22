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
# Usage: ./setup.sh
#        ./setup.sh --plain       # force number-typing menu (skip arrow keys)
#
# Safe to re-run. Preserves any other MCPs already configured.

set -euo pipefail

# ---------- flags ----------
FORCE_PLAIN=false
for arg in "$@"; do
  case "$arg" in
    --plain|-p) FORCE_PLAIN=true ;;
  esac
done

# ---------- pretty output ----------
BOLD=$'\033[1m'; DIM=$'\033[2m'; INV=$'\033[7m'
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

# ---------- can we use the fancy arrow-key menu? ----------
# We need:
#   - stdout is a real terminal (not piped/redirected)
#   - $TERM knows how to do cursor movement
#   - User didn't pass --plain
USE_FANCY=true
if [[ "$FORCE_PLAIN" == "true" ]]; then USE_FANCY=false; fi
if [[ ! -t 1 ]]; then USE_FANCY=false; fi
if [[ "${TERM:-dumb}" == "dumb" ]] || [[ -z "${TERM:-}" ]]; then USE_FANCY=false; fi
# tput sanity check — if these fail, fall back
if ! tput cup 0 0 >/dev/null 2>&1; then USE_FANCY=false; fi

# ---------- menu definitions ----------
MENU_OPTIONS=(
  "Claude Desktop"
  "Claude Code"
  "VS Code"
  "All of the above"
  "Show me where it's already connected"
)
DEFAULT_INDEX=3  # 0-based; points to "All of the above"

# ---------- arrow-key menu ----------
fancy_menu() {
  local selected=$DEFAULT_INDEX
  local count=${#MENU_OPTIONS[@]}
  local i
  local key key2

  # Hide cursor, ensure we restore it on any exit path
  tput civis
  trap 'tput cnorm' EXIT INT TERM

  # Initial draw
  echo "▸ Connect Figma to:"
  echo
  for (( i = 0; i < count; i++ )); do
    if [[ $i -eq $selected ]]; then
      printf "  ${BOLD}${MAGENTA}▸${RESET} ${BOLD}%s${RESET}\n" "${MENU_OPTIONS[i]}"
    else
      printf "    ${DIM}%s${RESET}\n" "${MENU_OPTIONS[i]}"
    fi
  done
  echo
  printf "  ${DIM}↑↓ arrows, Enter to confirm${RESET}\n"

  # Input loop
  while true; do
    key=""
    IFS= read -rsn1 key </dev/tty || true
    if [[ "$key" == $'\x1b' ]]; then
      key2=""
      IFS= read -rsn2 -t 0.05 key2 </dev/tty || true
      case "$key2" in
        '[A'|'OA') selected=$(( (selected - 1 + count) % count )) ;;
        '[B'|'OB') selected=$(( (selected + 1) % count )) ;;
        *) : ;;
      esac
    elif [[ -z "$key" ]]; then
      # Enter pressed
      break
    elif [[ "$key" == "q" ]] || [[ "$key" == "Q" ]]; then
      tput cnorm
      echo
      echo "  Cancelled."
      exit 0
    fi

    # Redraw: move cursor up past the menu + hint line
    tput cuu $(( count + 2 ))
    for (( i = 0; i < count; i++ )); do
      tput el
      if [[ $i -eq $selected ]]; then
        printf "  ${BOLD}${MAGENTA}▸${RESET} ${BOLD}%s${RESET}\n" "${MENU_OPTIONS[i]}"
      else
        printf "    ${DIM}%s${RESET}\n" "${MENU_OPTIONS[i]}"
      fi
    done
    tput el; echo
    tput el; printf "  ${DIM}↑↓ arrows, Enter to confirm${RESET}\n"
  done

  # Restore cursor
  tput cnorm
  trap - EXIT INT TERM

  PICKED_INDEX=$selected
}

# ---------- number-typing menu (fallback) ----------
plain_menu() {
  step "Connect Figma to:"
  local i
  for (( i = 0; i < ${#MENU_OPTIONS[@]}; i++ )); do
    printf "  %d) %s\n" $((i + 1)) "${MENU_OPTIONS[i]}"
  done
  echo
  printf "  ${DIM}(Type 1-%d, or Enter for %s)${RESET}\n" \
    ${#MENU_OPTIONS[@]} "${MENU_OPTIONS[DEFAULT_INDEX]}"
  echo
  prompt "Your pick:"
  local choice
  read -r choice </dev/tty || choice=""
  choice="${choice:-$((DEFAULT_INDEX + 1))}"
  if ! [[ "$choice" =~ ^[1-5]$ ]]; then
    err "Invalid choice."
    exit 1
  fi
  PICKED_INDEX=$((choice - 1))
}

# ---------- run the menu ----------
PICKED_INDEX=0
if [[ "$USE_FANCY" == "true" ]]; then
  fancy_menu
else
  plain_menu
fi

# Map to flags
DO_DESKTOP=0; DO_CODE=0; DO_VSCODE=0; DO_STATUS=0
case $PICKED_INDEX in
  0) DO_DESKTOP=1 ;;
  1) DO_CODE=1 ;;
  2) DO_VSCODE=1 ;;
  3) DO_DESKTOP=1; DO_CODE=1; DO_VSCODE=1 ;;
  4) DO_STATUS=1 ;;
esac

# ---------- status check (option 5) ----------
if [[ $DO_STATUS -eq 1 ]]; then
  step "Where Figma MCP is already connected"
  echo

  # Claude Desktop
  if [[ -f "$CLAUDE_DESKTOP_CONFIG" ]] \
     && python3 -c "
import json, sys
try:
  d = json.load(open(r'''$CLAUDE_DESKTOP_CONFIG'''))
  sys.exit(0 if 'figma' in (d.get('mcpServers') or {}) else 1)
except Exception:
  sys.exit(1)
" 2>/dev/null; then
    printf "  ${GREEN}✓${RESET} ${BOLD}Claude Desktop${RESET}   → figma MCP found in claude_desktop_config.json\n"
  else
    printf "  ${DIM}○ ${BOLD}Claude Desktop${RESET}   ${DIM}→ not configured${RESET}\n"
  fi

  # Claude Code
  if command -v claude >/dev/null 2>&1; then
    if claude mcp list 2>/dev/null | grep -q "^figma\b\|^figma "; then
      printf "  ${GREEN}✓${RESET} ${BOLD}Claude Code${RESET}      → figma in claude mcp list\n"
    else
      printf "  ${DIM}○ ${BOLD}Claude Code${RESET}      ${DIM}→ not configured${RESET}\n"
    fi
  else
    printf "  ${DIM}○ ${BOLD}Claude Code${RESET}      ${DIM}→ CLI not installed${RESET}\n"
  fi

  # VS Code
  if [[ -f "$VSCODE_MCP_CONFIG" ]] \
     && python3 -c "
import json, sys
try:
  d = json.load(open(r'''$VSCODE_MCP_CONFIG'''))
  sys.exit(0 if 'figma' in (d.get('servers') or {}) else 1)
except Exception:
  sys.exit(1)
" 2>/dev/null; then
    printf "  ${GREEN}✓${RESET} ${BOLD}VS Code${RESET}          → figma in mcp.json\n"
  else
    printf "  ${DIM}○ ${BOLD}VS Code${RESET}          ${DIM}→ not configured${RESET}\n"
  fi

  # Cowork (can't check programmatically)
  printf "  ${BLUE}?${RESET} ${BOLD}Cowork${RESET}           ${DIM}→ can't check from a script${RESET}\n"
  printf "    ${DIM}To verify: open Claude → Cowork tab → Customize → Connectors → Figma${RESET}\n"

  echo
  printf "  ${DIM}Re-run this script to add Figma to any app that's still unchecked.${RESET}\n"
  echo
  exit 0
fi

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
