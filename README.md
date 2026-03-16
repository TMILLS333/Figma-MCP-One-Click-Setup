# Figma MCP — One-Click Setup / 원클릭 설정

> **Language / 언어:** [English](#english) · [한국어](#한국어)

---

<details open>
<summary><h2 id="english">🇺🇸 English</h2></summary>

One-click setup for the [official Figma MCP server](https://www.figma.com/blog/figma-mcp/) on **macOS / Linux / Windows**.

### Why use this?

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

### Quick Start

#### macOS — Designers (one-click)

Double-click **Install Figma MCP.command** in Finder. Done.

#### macOS / Linux — Terminal

```bash
chmod +x setup.sh
./setup.sh
```

Requires **python3** (pre-installed on macOS and most Linux distros).

> **Note:** Claude Desktop requires **Node.js** (for `npx mcp-remote`) since it doesn't support the `url` transport directly. The setup script handles this automatically.

#### Windows — Designers (one-click)

Double-click **Install Figma MCP.bat** in File Explorer. Done.

#### Windows — PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

No external dependencies — uses native PowerShell JSON handling.

### What the script does

1. **Asks which mode** — remote (mcp.figma.com) or desktop (Figma Desktop, localhost:3845)
2. **Asks which client** — Claude Desktop, Claude Code, Cursor, VS Code, or all
3. **Merges** the server entry into each client's config file (preserving existing entries)
4. **Restarts Claude Desktop** if it was running (macOS / Windows)

The script never overwrites your other MCP servers — it reads existing JSON, adds/updates only the `figma` or `figma-desktop` entry, and writes it back.

### Re-running

Running the script again detects the existing setup and offers:

- **Switch mode** — toggle between remote and desktop (updates all configured clients)
- **Add/change client** — configure an additional client
- **Full re-setup** — start from scratch

Or pass `--force` (shell) / `-Force` (PowerShell) to skip detection.

### Config file locations

| Client | macOS | Linux | Windows |
|---|---|---|---|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |
| Claude Code | `~/.claude.json` | `~/.claude.json` | `%USERPROFILE%\.claude.json` |
| Cursor | `~/.cursor/mcp.json` | `~/.cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |
| VS Code | `~/Library/Application Support/Code/User/mcp.json` | `~/.config/Code/User/mcp.json` | `%APPDATA%\Code\User\mcp.json` |

### Desktop mode prerequisites

Before using the desktop server:

1. Install the latest **Figma Desktop** app
2. Open a Figma Design file
3. Toggle to **Dev Mode** (Shift+D)
4. Click **"Enable desktop MCP server"** in the inspect panel

The server runs at `http://127.0.0.1:3845/mcp` and only accepts local connections.

### Post-Setup: Restart & Authenticate (all clients)

After running the setup script, every client needs a **restart** and then an **OAuth authentication** on first use. The auth flow only triggers when you actually use a Figma-related prompt.

#### Cursor

1. **Fully quit Cursor** (Cmd+Q on macOS / Alt+F4 on Windows)
2. **Reopen Cursor**
3. Open the **Agent/Chat panel** and send a Figma prompt (e.g. *"Get the design context from [paste Figma URL]"*)
4. Cursor will open your browser for OAuth — click **Allow Access**

#### VS Code

1. **Restart VS Code** (Cmd+Q / Alt+F4, then reopen)
2. Open `mcp.json` — click **Start** above the `figma` server entry
3. VS Code will open your browser for OAuth — click **Allow Access**

#### Claude Desktop

1. The setup script auto-restarts Claude Desktop. If it didn't, **quit and reopen** it manually
2. Send a Figma prompt in the chat (e.g. *"Get the design context from [paste Figma URL]"*)
3. Claude Desktop will open your browser for OAuth — click **Allow Access**

#### Claude Code

1. **Restart Claude Code** if it was running
2. Type `/mcp` → select **figma** → click **Authenticate**
3. Claude Code will open your browser for OAuth — click **Allow Access**

> **Note:** Simply configuring the server is not enough — the OAuth flow only triggers after a restart and a Figma-related action.

### Troubleshooting

- **"python3 not found"** (macOS/Linux) — Install Python 3: `brew install python3` or `sudo apt install python3`
- **Config not updating** — Check that the config file contains valid JSON. Fix syntax errors, then re-run.
- **Claude Desktop not restarting** — Quit and reopen it manually, or run `pkill -f Claude && open -a "Claude"` on macOS.
- **OAuth prompt doesn't appear** — Restart your AI client after setup, then try a Figma-related prompt.
- **Cursor doesn't show Figma tools** — Make sure you fully quit and reopened Cursor after running setup. Check `~/.cursor/mcp.json` has the figma entry.
- **VS Code doesn't show Figma tools** — Check `~/Library/Application Support/Code/User/mcp.json` (macOS) has the figma entry.
- **Claude Code auth fails** — Try `claude mcp remove figma --scope user` then re-run the setup script.

</details>

---

<details>
<summary><h2 id="한국어">🇰🇷 한국어</h2></summary>

[공식 Figma MCP 서버](https://www.figma.com/blog/figma-mcp/)를 **macOS / Linux / Windows**에서 원클릭으로 설정합니다.

### 왜 사용하나요?

- 이 스크립트 없이는 앱 폴더 깊숙이 숨겨진 **JSON 설정 파일을 직접 찾아서 편집**해야 합니다
- 각 AI 클라이언트(Claude Desktop, Claude Code, Cursor, VS Code)는 MCP 설정을 **서로 다른 위치와 형식**으로 저장합니다
- 이 스크립트가 올바른 파일을 찾고, Figma 항목을 병합하며, **기존 설정을 보존**합니다 — 몇 초 만에
- API 토큰을 생성하거나 붙여넣을 필요 없음 — 공식 서버는 **OAuth** (브라우저 로그인) 사용

두 가지 서버 모드와 네 가지 AI 클라이언트를 지원합니다:

| 모드 | URL | 인증 |
|---|---|---|
| **리모트** | `https://mcp.figma.com/mcp` | OAuth (브라우저) |
| **데스크톱** | `http://127.0.0.1:3845/mcp` | Figma Desktop 개발 모드 |

| 클라이언트 | 설정 형식 |
|---|---|
| Claude Desktop | JSON 설정의 `mcpServers` |
| Claude Code | CLI (`claude mcp add`) 또는 JSON |
| Cursor | JSON 설정의 `mcpServers` |
| VS Code | `servers` + `"type": "http"` |

### 빠른 시작

#### macOS — 디자이너용 (원클릭)

Finder에서 **Install Figma MCP.command**를 더블클릭하세요. 끝.

#### macOS / Linux — 터미널

```bash
chmod +x setup.sh
./setup.sh
```

**python3**이 필요합니다 (macOS와 대부분의 Linux에 기본 설치되어 있습니다).

> **참고:** Claude Desktop은 `url` 전송을 직접 지원하지 않으므로 **Node.js** (`npx mcp-remote` 용)가 필요합니다. 설정 스크립트가 이를 자동으로 처리합니다.

#### Windows — 디자이너용 (원클릭)

파일 탐색기에서 **Install Figma MCP.bat**를 더블클릭하세요. 끝.

#### Windows — PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

외부 의존성 없음 — 기본 PowerShell JSON 처리를 사용합니다.

### 스크립트 동작 방식

1. **모드 선택** — 리모트 (mcp.figma.com) 또는 데스크톱 (Figma Desktop, localhost:3845)
2. **클라이언트 선택** — Claude Desktop, Claude Code, Cursor, VS Code, 또는 전체
3. 각 클라이언트의 설정 파일에 서버 항목을 **병합** (기존 항목 보존)
4. Claude Desktop이 실행 중이면 **자동 재시작** (macOS / Windows)

이 스크립트는 다른 MCP 서버를 덮어쓰지 않습니다 — 기존 JSON을 읽고, `figma` 또는 `figma-desktop` 항목만 추가/업데이트한 후 다시 저장합니다.

### 재실행

스크립트를 다시 실행하면 기존 설정을 감지하고 다음을 제안합니다:

- **모드 전환** — 리모트와 데스크톱 사이 전환 (설정된 모든 클라이언트 업데이트)
- **클라이언트 추가/변경** — 추가 클라이언트 설정
- **전체 재설정** — 처음부터 다시 시작

`--force` (shell) / `-Force` (PowerShell)를 전달하면 감지를 건너뜁니다.

### 설정 파일 위치

| 클라이언트 | macOS | Linux | Windows |
|---|---|---|---|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |
| Claude Code | `~/.claude.json` | `~/.claude.json` | `%USERPROFILE%\.claude.json` |
| Cursor | `~/.cursor/mcp.json` | `~/.cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |
| VS Code | `~/Library/Application Support/Code/User/mcp.json` | `~/.config/Code/User/mcp.json` | `%APPDATA%\Code\User\mcp.json` |

### 데스크톱 모드 사전 요구 사항

데스크톱 서버를 사용하기 전에:

1. 최신 **Figma Desktop** 앱 설치
2. Figma 디자인 파일 열기
3. **개발 모드**로 전환 (Shift+D)
4. 검사 패널에서 **"Enable desktop MCP server"** 클릭

서버는 `http://127.0.0.1:3845/mcp`에서 실행되며 로컬 연결만 허용합니다.

### 설정 후: 재시작 및 인증 (모든 클라이언트)

설정 스크립트 실행 후, 모든 클라이언트는 **재시작**과 첫 사용 시 **OAuth 인증**이 필요합니다. 인증 절차는 Figma 관련 프롬프트를 실제로 사용할 때만 시작됩니다.

#### Cursor

1. **Cursor를 완전히 종료** (macOS: Cmd+Q / Windows: Alt+F4)
2. **Cursor 재실행**
3. **Agent/Chat 패널**을 열고 Figma 프롬프트 전송 (예: *"Get the design context from [Figma URL 붙여넣기]"*)
4. 브라우저가 열리면 OAuth 인증 — **Allow Access** 클릭

#### VS Code

1. **VS Code 재시작** (Cmd+Q / Alt+F4 후 재실행)
2. `mcp.json`을 열고 — `figma` 서버 항목 위의 **Start** 클릭
3. 브라우저가 열리면 OAuth 인증 — **Allow Access** 클릭

#### Claude Desktop

1. 설정 스크립트가 Claude Desktop을 자동 재시작합니다. 안 됐다면 **직접 종료 후 재실행**
2. 채팅에서 Figma 프롬프트 전송 (예: *"Get the design context from [Figma URL 붙여넣기]"*)
3. 브라우저가 열리면 OAuth 인증 — **Allow Access** 클릭

#### Claude Code

1. 실행 중이면 **Claude Code 재시작**
2. `/mcp` 입력 → **figma** 선택 → **Authenticate** 클릭
3. 브라우저가 열리면 OAuth 인증 — **Allow Access** 클릭

> **참고:** 서버를 설정하는 것만으로는 충분하지 않습니다 — OAuth 절차는 재시작 후 Figma 관련 작업을 수행할 때만 시작됩니다.

### 문제 해결

- **"python3 not found"** (macOS/Linux) — Python 3 설치: `brew install python3` 또는 `sudo apt install python3`
- **설정이 업데이트되지 않음** — 설정 파일이 유효한 JSON인지 확인하세요. 구문 오류를 수정한 후 다시 실행하세요.
- **Claude Desktop이 재시작되지 않음** — 수동으로 종료 후 재실행하거나, macOS에서 `pkill -f Claude && open -a "Claude"` 실행
- **OAuth 프롬프트가 나타나지 않음** — 설정 후 AI 클라이언트를 재시작한 다음 Figma 관련 프롬프트를 시도하세요.
- **Cursor에서 Figma 도구가 보이지 않음** — 설정 실행 후 Cursor를 완전히 종료하고 재실행했는지 확인하세요. `~/.cursor/mcp.json`에 figma 항목이 있는지 확인하세요.
- **VS Code에서 Figma 도구가 보이지 않음** — `~/Library/Application Support/Code/User/mcp.json` (macOS)에 figma 항목이 있는지 확인하세요.
- **Claude Code 인증 실패** — `claude mcp remove figma --scope user` 실행 후 설정 스크립트를 다시 실행하세요.

</details>
