# Security Audit

I forked this project specifically to verify it's safe to hand to non-technical designers. This document records what was checked, what was found, and what you're actually trusting when you run the installer.

If you're distributing this fork or recommending it to others, read this first.

---

## TL;DR

- The scripts in this repo do not download or execute any remote code themselves.
- They read and write JSON files in your user directory (`~/Library/...` on macOS, `%APPDATA%` on Windows).
- They shell out to three benign tools: `python3` (JSON merge), `claude` (your own CLI), and the OS app launcher (`open` / `Start-Process`).
- There is **one** external runtime dependency, introduced only for Claude Desktop: the npm package [`mcp-remote`](https://www.npmjs.com/package/mcp-remote), which is pulled via `npx` and runs as a local proxy. It's a legitimate package — see below.
- No telemetry, no analytics, no network callbacks to any server we control.

I found no malware, no obfuscated code, and no evidence of exfiltration.

---

## What the installer actually does

The install scripts (`setup.sh` and `setup.ps1`) do exactly these things:

1. **Detect your OS** via `uname` / PowerShell environment.
2. **Check for `node` and `python3`** (only relevant for Claude Desktop / VS Code merge steps). These are presence checks, not installs.
3. **Back up your existing config** to `claude_desktop_config.json.backup.YYYYMMDD-HHMMSS` before writing.
4. **Load the existing JSON** with the stdlib parser (`json.loads` on macOS/Linux, `ConvertFrom-Json` on Windows).
5. **Merge in a single entry** for the Figma MCP under the `mcpServers` (or `servers` for VS Code) key.
6. **Write the file back** with the same parser's serializer.
7. **Optionally shell out** to `claude mcp add` (if you have the Claude Code CLI) and to `open -a Claude` / `Start-Process` (to restart Claude Desktop).

That's it. Nothing else.

---

## What I checked

### 1. Hardcoded URLs

Both endpoints are literal string constants, never constructed from user input or environment variables:

| Constant | Value | Notes |
|---|---|---|
| Figma remote MCP | `https://mcp.figma.com/mcp` | Figma's official domain |
| Figma desktop MCP *(not used in this fork)* | `http://127.0.0.1:3845/mcp` | Localhost only |

No config-driven URLs, no redirections. If a future PR adds one, audit it before merging.

### 2. Shell-outs

Every external command run by the scripts:

| Command | What it does | Risk |
|---|---|---|
| `python3` | Runs an inline heredoc to merge JSON. Arguments passed via `sys.argv`, not string interpolation. | Low — immune to command injection. |
| `claude mcp add` | Adds Figma to Claude Code's config via the official CLI. | Low — uses the user's own `claude` binary. |
| `claude mcp list` / `claude mcp remove` | Reads/removes existing config. | Low — same as above. |
| `osascript -e 'quit app "Claude"'` (macOS) | Politely asks Claude to quit via Apple Events. | Low — no elevated privileges. |
| `open -a "Claude"` (macOS) | Launches Claude Desktop. | Low — standard macOS command. |
| `Start-Process <Claude.exe>` (Windows) | Launches Claude Desktop. | Low — uses path resolved from `%LOCALAPPDATA%` / `%ProgramFiles%`, not user input. |
| `Stop-Process -Name Claude -Force` (Windows) | Kills the Claude process so it restarts cleanly. | Low — only targets `Claude.exe`. |

No `eval`, no `curl | bash`, no dynamic module loading inside the scripts themselves.

### 3. The curl one-liner in README

```bash
curl -fsSL https://raw.githubusercontent.com/TMILLS333/Figma-MCP-One-Click-Setup/main/setup.sh | bash
```

This is a standard "pipe to shell" pattern. It fetches `setup.sh` from this repo's `main` branch over HTTPS. Because you control the repo, you control the content. The risk model is the same as any `curl | bash` install — if an attacker compromises the GitHub account or repo, they could ship arbitrary code. Mitigations:

- Enable 2FA on the GitHub account that owns this repo (required by GitHub for contributions in any case).
- Pin the one-liner to a specific commit SHA or tag in the README if you want stronger guarantees (e.g., `.../raw/v1.0.0/setup.sh`).

For non-technical designers, the double-click install (ZIP download) is safer because they see the scripts before running them.

### 4. File writes

Every file the scripts write lives inside the user's own directory:

- `~/Library/Application Support/Claude/claude_desktop_config.json`
- `~/Library/Application Support/Code/User/mcp.json`
- `~/.cursor/mcp.json` *(not used in this fork, but the reference writes here)*
- `%APPDATA%\Claude\claude_desktop_config.json`
- `%APPDATA%\Code\User\mcp.json`

Plus sibling `.backup.TIMESTAMP` files next to each. No writes to `/etc`, no writes to `/usr`, no writes to `C:\Windows`, no launchd or scheduled tasks installed.

### 5. JSON merge safety

Both the Python heredoc and the PowerShell JSON cmdlets use stdlib parsers. There's no custom string concatenation building JSON, and the Figma entry itself is built from literal constants. A malicious *existing* config can't cause arbitrary code execution during the merge — at worst it triggers a JSON parse error, which we catch and handle by starting fresh (after backing up the broken file).

### 6. The one external runtime dependency: `mcp-remote`

When Claude Desktop loads the Figma MCP, it runs:

```
npx -y mcp-remote https://mcp.figma.com/mcp
```

This downloads and runs the `mcp-remote` package from npm on every Claude Desktop startup. That package is the only non-OS code invoked at runtime by this setup. Here's what I verified:

| Field | Value |
|---|---|
| Package | [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) |
| Latest version | 0.1.38 (at time of audit, April 2026) |
| Author | Glen Maddern `<glen@glenmaddern.com>` |
| Maintainers on npm | `geelen` (Glen Maddern), `threepointone` (Sunil Pai) |
| Repo | https://github.com/geelen/mcp-remote |
| License | MIT |
| Purpose | Proxy that lets local-only MCP clients (like Claude Desktop) connect to remote OAuth MCP servers |
| Runtime deps | `express`, `open`, `strict-url-sanitise`, `undici` — all standard, widely used |

Both maintainers are publicly known, long-standing open-source identities. Glen Maddern (`geelen`) works at Cloudflare and has published widely used JS tooling for years. Sunil Pai (`threepointone`) is a former React core team member and also at Cloudflare. This is the de-facto package for this purpose in the MCP ecosystem.

**Residual risk:** if `geelen`'s or `threepointone`'s npm account is compromised, or if a malicious version is published in the future, `npx -y mcp-remote` would fetch and run it on the next Claude Desktop start. This is the same supply-chain risk any npm-based install carries. To mitigate:

- Pin a specific version in the Claude Desktop config: change `"args": ["-y", "mcp-remote", ...]` to `"args": ["-y", "mcp-remote@0.1.38", ...]`. Downside: you won't get auto-updates if a security fix lands.
- Watch the [repo](https://github.com/geelen/mcp-remote) for advisories.
- Consider switching Claude Desktop to the Cowork connector flow for Figma instead — Cowork uses Anthropic's cloud proxy rather than a local `mcp-remote` wrapper, avoiding this dependency entirely.

### 7. No telemetry

I grepped the scripts for any outbound network call, analytics endpoint, webhook, or ping-home pattern. None found. The scripts do not report installs, errors, or usage anywhere.

### 8. Double-click wrappers

`Install Figma MCP.command` and `Install Figma MCP.bat` are thin wrappers. The `.command` file sources its own directory, chmods `setup.sh`, and runs it with `bash`. The `.bat` calls PowerShell with `-ExecutionPolicy Bypass` scoped to that single invocation (a standard pattern for unsigned first-run installers; it does not permanently change your system policy).

---

## What this fork changed vs. upstream

This repo is forked from [`sso-ss/Figma-MCP-One-Click-Setup`](https://github.com/sso-ss/Figma-MCP-One-Click-Setup). Changes with security implications:

- **No functional code was removed or weakened.** Backup behavior, JSON parsing approach, and all shell-outs match upstream or are strictly narrower.
- **Cowork guidance added** — the Cowork section prints instructions and optionally calls `open -a Claude`. No config file edits for Cowork (because Cowork installs connectors through its UI, not a JSON file).
- **Cursor support removed** — one fewer config file written. This narrows the footprint.
- **VS Code support retained.**
- **Remote-only mode** — the local Figma Desktop endpoint (`127.0.0.1:3845`) is not used in this fork. Simpler menu, one less endpoint to audit per run.

---

## How to verify yourself

You can reproduce the audit with these commands on any checkout of this repo:

```bash
# Look for any obviously suspicious pattern
grep -nE 'curl|wget|eval|exec|base64|fetch|Invoke-Expression|Invoke-WebRequest' setup.sh setup.ps1

# Inspect every external command that gets run
grep -nE '^\s*(python3|node|npx|claude|open|osascript|Start-Process|Stop-Process)' setup.sh setup.ps1

# Confirm the only URLs are Figma's
grep -oE 'https?://[^ "\)]+' setup.sh setup.ps1 | sort -u
```

For the runtime dependency:

```bash
# See the mcp-remote package metadata
curl -s https://registry.npmjs.org/mcp-remote/latest | python3 -m json.tool
```

---

## Reporting issues

Found something? Open an issue on [this repo](https://github.com/TMILLS333/Figma-MCP-One-Click-Setup/issues) or flag it privately.

---

*Last audited: April 2026, against commit on `main` branch at the time of this document's creation.*
