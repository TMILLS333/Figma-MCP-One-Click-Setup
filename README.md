# Figma MCP — One-Click Setup

Connect Figma to Claude in one double-click. For designers, by a designer.

Works with:
- **Claude Desktop**
- **Claude Code** (terminal)
- **Cowork** (the "Cowork" tab inside Claude Desktop)

On **macOS** and **Windows**. No Node.js knowledge, no JSON editing, no tokens — the official Figma MCP uses OAuth, so you just click "Allow" in Figma once and you're done.

---

## The easy way (double-click)

1. Download this folder as a ZIP (green **Code** button on GitHub → **Download ZIP**) and unzip it.
2. Double-click the installer for your OS:
   - **macOS:** `Install Figma MCP.command`
   - **Windows:** `Install Figma MCP.bat`
3. Follow the prompts. The script will:
   - Add the Figma MCP to Claude Desktop's config
   - Add it to Claude Code (if installed)
   - Walk you through the two clicks for Cowork
4. Restart Claude Desktop (the script offers to do it for you on macOS).
5. In Claude, sign in to Figma when prompted. Done.

### First-time macOS warning

macOS may say *"'Install Figma MCP.command' cannot be opened because it is from an unidentified developer."* That's normal for scripts you download. Fix:

- Right-click (or Control-click) the file → **Open** → **Open** again in the dialog that appears.
- Or run `xattr -d com.apple.quarantine "Install Figma MCP.command"` in Terminal once.

After that one-time approval, double-clicking works like any other app.

---

## The terminal way (one line)

If you live in the terminal:

**macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/TMILLS333/Figma-MCP-One-Click-Setup/main/setup.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/TMILLS333/Figma-MCP-One-Click-Setup/main/setup.ps1 | iex
```

---

## What the script does

1. Asks which client(s) to configure (Claude Desktop / Claude Code / Cowork — pick any combo).
2. Finds your Claude Desktop config file automatically and merges the Figma MCP entry in. If the file already has other MCPs, those are left alone.
3. If you have Claude Code installed, runs `claude mcp add` for you.
4. For Cowork, prints the two-click path (Customize → Figma → Connect) and can pop open Claude to the right place.
5. Offers to restart Claude Desktop so the new config loads.

It's safe to re-run — the script detects an existing install and offers to switch modes, add a client, or re-do everything from scratch.

---

## What each client gets

| Client | Where it ends up |
|---|---|
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)<br>`%APPDATA%\Claude\claude_desktop_config.json` (Windows)<br>Uses `npx mcp-remote` to handle Figma's OAuth, so you'll need Node.js installed for Claude Desktop specifically. The script checks and tells you if you're missing it. |
| **Claude Code** | Stored under your user scope via `claude mcp add`. Run `claude mcp list` to verify. |
| **Cowork** | Figma is an official connector in Cowork's registry. Open Claude → Cowork tab → **Customize** (left sidebar) → **Browse connectors** → **Figma** → **Connect**. Sign in to Figma, click Allow. Done. |

---

## Authenticating with Figma

The first time Claude tries to use Figma, it'll prompt you to authenticate:

1. A Figma login page opens in your browser.
2. Sign in with your Figma account.
3. Click **Allow** to give Claude permission.
4. Come back to Claude. You're connected.

No personal access tokens, no copy-pasting secrets. OAuth handles it.

---

## Test it

In Claude (any surface), type:

```
List MCP tools
```

If you see tools like `get_design_context`, `get_screenshot`, `get_metadata`, `get_variable_defs`, and `use_figma`, you're connected.

Then try something real:

- *"Open this Figma file and check the main frame for accessibility issues: [paste Figma URL]"*
- *"Extract the design tokens (colors, spacing, typography) from this file."*
- *"Generate the CSS for this selected component."*

---

## Troubleshooting

**"Node.js not found" on macOS**
Run `brew install node`. If you don't have Homebrew, install it from [brew.sh](https://brew.sh). Or download Node from [nodejs.org](https://nodejs.org).

**"Node.js not found" on Windows**
Download the installer from [nodejs.org](https://nodejs.org) and run it. Then re-run the script.

**OAuth prompt doesn't appear in Claude Desktop**
Fully quit Claude Desktop (Cmd+Q / right-click tray icon → Quit), then reopen. MCPs only load on full startup.

**Claude Code auth fails**
Remove and re-add:
```bash
claude mcp remove figma --scope user
```
Then re-run this setup.

**I want to remove the Figma MCP**
- **Claude Desktop:** edit `claude_desktop_config.json` and delete the `"figma"` entry under `"mcpServers"`. Save and restart Claude Desktop.
- **Claude Code:** `claude mcp remove figma --scope user`
- **Cowork:** Customize menu → Connectors → Figma → Disconnect.

---

## What's in this repo

| File | What it's for |
|---|---|
| `Install Figma MCP.command` | Double-click me on macOS |
| `Install Figma MCP.bat` | Double-click me on Windows |
| `setup.sh` | The actual work on macOS / Linux |
| `setup.ps1` | The actual work on Windows |
| `README.md` | You are here |

---

## Why this exists

Setting up MCPs by hand means digging into hidden `~/Library/...` folders, editing JSON you've never seen before, learning the three different places each client stores its config, and hoping you didn't miss a comma. That's not the right first experience for designers who just want Claude to see their Figma file.

This installer hides all of it.

Part of **How to Platypus** — the educational program at [weareplatypus.com](https://weareplatypus.com), teaching multi-disciplinary professionals how to work with AI.

---

## Credit

Inspired by and forked from [`sso-ss/Figma-MCP-One-Click-Setup`](https://github.com/sso-ss/Figma-MCP-One-Click-Setup). Extended to support Cowork and simplified for non-technical designers.
