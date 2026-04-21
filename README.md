# Figma MCP — One-Click Setup

Connect Figma to Claude and VS Code in one double-click.

Works with:
- **Claude Desktop**
- **Claude Code** (terminal)
- **Cowork** (the "Cowork" tab inside Claude Desktop)
- **VS Code**

On **macOS** and **Windows**. No Node.js knowledge, no JSON editing, no tokens — the official Figma MCP uses OAuth, so you just click "Allow" in Figma once and you're done.

---

## The easy way (double-click)

1. Download this folder as a ZIP (green **Code** button above → **Download ZIP**) and unzip it.
2. Double-click the installer for your OS:
   - **macOS:** `Install Figma MCP.command`
   - **Windows:** `Install Figma MCP.bat`
3. Follow the prompts. The script will:
   - Add the Figma MCP to Claude Desktop's config
   - Add it to Claude Code (if installed)
   - Add it to VS Code's `mcp.json`
   - Walk you through the two clicks for Cowork
4. Restart Claude Desktop (the script offers to do it for you on macOS).
5. In Claude or VS Code, sign in to Figma when prompted. Done.

### First-time macOS warning

macOS blocks scripts downloaded from the internet on first run. You'll see one of two dialogs.

**Older dialog** — *"cannot be opened because it is from an unidentified developer"* with an **Open** button available via right-click:

- Right-click (or Control-click) the file → **Open** → **Open** again in the dialog.

**Newer dialog (macOS Sequoia and later)** — *"Apple could not verify … is free of malware"* with only **Move to Trash** / **Done** buttons (no Open option). Pick any one of these:

**Option A — Fix it in Terminal (fastest):**
```bash
xattr -cr ~/Downloads/Figma-MCP-One-Click-Setup-main
```
Replace the path with wherever you unzipped it. `xattr -cr` clears the quarantine attribute from every file in the folder, recursively. Then double-click the installer again — it'll open.

*Tip: drag the unzipped folder from Finder into Terminal to auto-paste the correct path.*

**Option B — Skip the double-click entirely:**
```bash
bash ~/Downloads/Figma-MCP-One-Click-Setup-main/setup.sh
```
Running `setup.sh` directly with bash bypasses Gatekeeper — you're telling your shell to run it explicitly.

**Option C — The GUI way (no Terminal):**
1. Click **Done** on the warning dialog.
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the **Security** section.
4. You'll see a line about `"Install Figma MCP.command" was blocked`, with an **Open Anyway** button.
5. Click it, authenticate with Touch ID / password, then double-click the `.command` file again.

After any one of these, double-clicking works like any other app.

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

## What each client gets

| Client | Where it ends up |
|---|---|
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) / `%APPDATA%\Claude\claude_desktop_config.json` (Windows). Uses `npx mcp-remote` to handle Figma's OAuth, so you'll need Node.js installed for Claude Desktop specifically. The script checks and tells you if you're missing it. |
| **Claude Code** | Stored under your user scope via `claude mcp add`. Run `claude mcp list` to verify. |
| **Cowork** | Figma is an official connector in Cowork's registry. Open Claude → Cowork tab → **Customize** → **Browse connectors** → **Figma** → **Connect**. Sign in to Figma, click Allow. Done. |
| **VS Code** | `~/Library/Application Support/Code/User/mcp.json` (macOS) / `%APPDATA%\Code\User\mcp.json` (Windows). Uses a direct HTTP transport — no Node.js required. Open the file in VS Code and click **Start** above the figma entry. |

---

## Authenticating with Figma

The first time Claude (or VS Code) tries to use Figma, it'll prompt you to authenticate:

1. A Figma login page opens in your browser.
2. Sign in with your Figma account.
3. Click **Allow** to give the app permission.
4. Come back to Claude / VS Code. You're connected.

No personal access tokens, no copy-pasting secrets. OAuth handles it.

---

## Test it

In Claude (any surface) or VS Code chat, type:

```
List MCP tools
```

If you see tools like `get_design_context`, `get_screenshot`, `get_metadata`, `get_variable_defs`, and `use_figma`, you're connected.

---

## What you can do with the Figma MCP

The official Figma MCP gives Claude and VS Code a set of tools for reading, inspecting, and even modifying Figma files. Here's what each one does, with prompts you can paste directly.

### Read and inspect designs

**`get_design_context`** — the workhorse. Pulls reference code, a screenshot, *and* metadata for any node in one call. This is what "design-to-code" runs on.
> *"Open this Figma file and give me the full design context for the selected frame: [paste Figma URL]"*
> *"Using get_design_context on this node, generate clean React + Tailwind code that matches."*

**`get_metadata`** — lightweight node inspection without generating code. Good when you just want structure.
> *"What's the layout hierarchy of this frame? Use get_metadata, don't generate code yet."*

**`get_screenshot`** — exports a PNG of a specific frame, component, or page.
> *"Take a screenshot of the `Hero` frame so I can drop it into a doc."*

**`get_figjam`** — reads FigJam boards (sticky notes, connectors, sections).
> *"Summarize the user research synthesis on this FigJam board: [URL]"*

### Design system and tokens

**`get_variable_defs`** — extracts design tokens and variables (colors, spacing, typography values).
> *"Extract all color and spacing tokens from this file and give them to me as CSS custom properties."*
> *"List the typography scale from this Figma file as a Tailwind config snippet."*

**`search_design_system`** — searches across connected libraries for components, styles, and variables.
> *"Search the design system for any button component that uses the primary color token."*

**`create_design_system_rules`** — generates rules or guidance derived from your design system.
> *"Look at this file and write design system rules I can hand to a new designer joining the team."*

**`get_code_connect_map`** — returns the Code Connect mappings between Figma components and code.
> *"Show me which components have Code Connect mappings and which don't."*

**`get_context_for_code_connect`** — structured metadata used to *build* Code Connect mappings.
> *"For this Button component, give me the Code Connect template so I can link it to our React component."*

### Create and modify (write access)

**`use_figma`** — runs Plugin API code directly. Can create frames, components, text, layouts, variables — anything the Figma Plugin API can.
> *"Create a new frame in this file with a 3-column dashboard layout using our primary colors."*
> *"Duplicate the selected card and arrange 6 copies in a 3×2 grid."*
> *"Rename every auto-layout frame whose name starts with 'Component/' so it starts with 'Patterns/' instead."*

### Diagrams and diagrams-to-code

**`generate_diagram`** — creates diagrams from a description, inside Figma.
> *"Generate a sequence diagram showing the OAuth flow between Claude, the Figma MCP, and Figma's servers."*

### What's *not* listed here

The Figma MCP gets updates. If you see a tool in `List MCP tools` that isn't in this README, it's probably new — run it and see what it does, the names are pretty self-describing.

---

## Troubleshooting

**"Node.js not found" on macOS**
Run `brew install node`. If you don't have Homebrew, install it from [brew.sh](https://brew.sh). Or download Node from [nodejs.org](https://nodejs.org). *VS Code doesn't need Node — only Claude Desktop does.*

**"Node.js not found" on Windows**
Download the installer from [nodejs.org](https://nodejs.org) and run it. Then re-run the script.

**OAuth prompt doesn't appear in Claude Desktop**
Fully quit Claude Desktop (Cmd+Q on Mac, or right-click tray icon → Quit on Windows), then reopen. MCPs only load on full startup.

**Claude Code auth fails**
Remove and re-add:
```bash
claude mcp remove figma --scope user
```
Then re-run this setup.

**VS Code shows the server but it won't start**
Open `mcp.json` in VS Code. There's a small **Start** button above the `figma` entry — click it. First start triggers the OAuth flow in your browser.

**I want to remove the Figma MCP**
- **Claude Desktop:** edit `claude_desktop_config.json` and delete the `"figma"` entry under `"mcpServers"`. Save and restart Claude Desktop.
- **Claude Code:** `claude mcp remove figma --scope user`
- **Cowork:** Customize menu → Connectors → Figma → Disconnect.
- **VS Code:** open `mcp.json` and delete the `"figma"` entry under `"servers"`.

---

## Security

Short version: the scripts only edit JSON config files in your own user directory. They don't download or run any remote code themselves. See [`SECURITY.md`](./SECURITY.md) for the full audit — what was checked, what was found, and the one external runtime dependency (`mcp-remote`, used only by Claude Desktop to wrap OAuth).

---

## What's in this repo

| File | What it's for |
|---|---|
| `Install Figma MCP.command` | Double-click me on macOS |
| `Install Figma MCP.bat` | Double-click me on Windows |
| `setup.sh` | The actual work on macOS / Linux |
| `setup.ps1` | The actual work on Windows |
| `SECURITY.md` | Security audit of this fork |
| `README.md` | You are here |

---

## Credit

Forked from and heavily inspired by [`sso-ss/Figma-MCP-One-Click-Setup`](https://github.com/sso-ss/Figma-MCP-One-Click-Setup). This fork adds Cowork support, simplifies the menu for non-technical users, and includes a security audit.
