# Figma MCP — One-Click Setup

One-click setup for the [official Figma MCP server](https://www.figma.com/blog/figma-mcp/) on **macOS / Linux / Windows**.

## Why use this?

- Without this, you'd have to **manually find and edit JSON config files** buried in app-specific folders
- Each AI client (Claude Desktop, Claude Code, Cursor, VS Code) stores MCP settings in a **different location and format**
- This script finds the right file, merges the Figma entry, and **preserves your existing settings** — in seconds
- No API tokens to generate or paste — the official server uses **OAuth** (browser sign-in)

Supports two server modes and four AI clients:

| Mode | URL | Auth |
|---|---|---|
| **Remote** | `https://mcp.figma.com/mcp` | OAuth (browser) |
| **Desktop** | `http://127.0.0.1:3845/mcp` | Figma Desktop Dev Mode |

| Client | Config format |
|---|---|
| Claude Desktop | `mcpServers` in JSON config |
| Claude Code | CLI (`claude mcp add`) or JSON |
| Cursor | `mcpServers` in JSON config |
| VS Code | `servers` + `"type": "http"` |

## Quick Start

### macOS / Linux

```bash
chmod +x setup.sh
./setup.sh
```

Requires **python3** (pre-installed on macOS and most Linux distros).

### Windows

Double-click **setup.bat**, or run in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

No external dependencies — uses native PowerShell JSON handling.

## What the script does

1. **Asks which mode** — remote (mcp.figma.com) or desktop (Figma Desktop, localhost:3845)
2. **Asks which client** — Claude Desktop, Claude Code, Cursor, VS Code, or all
3. **Merges** the server entry into each client's config file (preserving existing entries)
4. **Restarts Claude Desktop** if it was running (macOS / Windows)

The script never overwrites your other MCP servers — it reads existing JSON, adds/updates only the `figma` or `figma-desktop` entry, and writes it back.

## Re-running

Running the script again detects the existing setup and offers:

- **Switch mode** — toggle between remote and desktop (updates all configured clients)
- **Add/change client** — configure an additional client
- **Full re-setup** — start from scratch

Or pass `--force` (shell) / `-Force` (PowerShell) to skip detection.

## Config file locations

| Client | macOS | Linux | Windows |
|---|---|---|---|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |
| Claude Code | `~/.claude.json` | `~/.claude.json` | `%USERPROFILE%\.claude.json` |
| Cursor | `~/.cursor/mcp.json` | `~/.cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |
| VS Code | `~/Library/Application Support/Code/User/mcp.json` | `~/.config/Code/User/mcp.json` | `%APPDATA%\Code\User\mcp.json` |

## Desktop mode prerequisites

Before using the desktop server:

1. Install the latest **Figma Desktop** app
2. Open a Figma Design file
3. Toggle to **Dev Mode** (Shift+D)
4. Click **"Enable desktop MCP server"** in the inspect panel

The server runs at `http://127.0.0.1:3845/mcp` and only accepts local connections.

## Post-Setup: Restart & Authenticate (all clients)

After running the setup script, every client needs a **restart** and then an **OAuth authentication** on first use. The auth flow only triggers when you actually use a Figma-related prompt.

### Cursor

1. **Fully quit Cursor** (Cmd+Q on macOS / Alt+F4 on Windows)
2. **Reopen Cursor**
3. Open the **Agent/Chat panel** and send a Figma prompt (e.g. *"Get the design context from [paste Figma URL]"*)
4. Cursor will open your browser for OAuth — click **Allow Access**

### VS Code

1. **Restart VS Code** (Cmd+Q / Alt+F4, then reopen)
2. Open `mcp.json` — click **Start** above the `figma` server entry
3. VS Code will open your browser for OAuth — click **Allow Access**

### Claude Desktop

1. The setup script auto-restarts Claude Desktop. If it didn't, **quit and reopen** it manually
2. Send a Figma prompt in the chat (e.g. *"Get the design context from [paste Figma URL]"*)
3. Claude Desktop will open your browser for OAuth — click **Allow Access**

### Claude Code

1. **Restart Claude Code** if it was running
2. Type `/mcp` → select **figma** → click **Authenticate**
3. Claude Code will open your browser for OAuth — click **Allow Access**

> **Note:** Simply configuring the server is not enough — the OAuth flow only triggers after a restart and a Figma-related action.

## Troubleshooting

- **"python3 not found"** (macOS/Linux) — Install Python 3: `brew install python3` or `sudo apt install python3`
- **Config not updating** — Check that the config file contains valid JSON. Fix syntax errors, then re-run.
- **Claude Desktop not restarting** — Quit and reopen it manually, or run `pkill -f Claude && open -a "Claude"` on macOS.
- **OAuth prompt doesn't appear** — Restart your AI client after setup, then try a Figma-related prompt.
- **Cursor doesn't show Figma tools** — Make sure you fully quit and reopened Cursor after running setup. Check `~/.cursor/mcp.json` has the figma entry.
- **VS Code doesn't show Figma tools** — Check `~/Library/Application Support/Code/User/mcp.json` (macOS) has the figma entry.
- **Claude Code auth fails** — Try `claude mcp remove figma --scope user` then re-run the setup script.
