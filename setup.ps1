# Figma MCP - One-Click Setup (Windows PowerShell)
#
# Adds the official Figma MCP (https://mcp.figma.com/mcp, OAuth) to:
#   - Claude Desktop
#   - Claude Code
#   - VS Code
#
# Cowork uses a 2-click UI flow (Customize -> Figma -> Connect) and isn't
# scriptable, so it's documented in the README/landing page instead.
#
# Safe to re-run. Preserves any other MCPs already configured.
# Uses native PowerShell JSON - no external dependencies.

$ErrorActionPreference = 'Stop'

# ---------- pretty output ----------
function Write-Step($msg)   { Write-Host ""; Write-Host "> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)     { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg)  { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Err2($msg)   { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Prompt-YN($q, $default='Y') {
  $suffix = if ($default -eq 'Y') { '[Y/n]' } else { '[y/N]' }
  $ans = Read-Host "$q $suffix"
  if ([string]::IsNullOrWhiteSpace($ans)) { $ans = $default }
  return ($ans -match '^[Yy]')
}

# ---------- config paths ----------
$ClaudeDesktopDir    = Join-Path $env:APPDATA 'Claude'
$ClaudeDesktopConfig = Join-Path $ClaudeDesktopDir 'claude_desktop_config.json'
$VSCodeUserDir       = Join-Path $env:APPDATA 'Code\User'
$VSCodeMcpConfig     = Join-Path $VSCodeUserDir 'mcp.json'
$FigmaMcpUrl         = 'https://mcp.figma.com/mcp'

# ---------- banner ----------
Clear-Host
Write-Host ""
Write-Host "  +--+  +--+  +--+" -ForegroundColor White
Write-Host "  |  |  |  |  |  |" -NoNewline -ForegroundColor White
Write-Host "     Figma MCP - One-Click Setup" -ForegroundColor White
Write-Host "  +--+  +--+  +--+" -NoNewline -ForegroundColor White
Write-Host "     design -> AI" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Safe to re-run." -ForegroundColor DarkGray
Write-Host ""

# ---------- which apps? ----------
# Cowork is handled separately (2-click UI flow documented in README + landing page),
# so it's not part of the scripted install.
Write-Step "Which apps do you want to set up?"
Write-Host "  1) All - Claude Desktop, Claude Code, and VS Code"
Write-Host "  2) Claude Desktop"
Write-Host "  3) Claude Code"
Write-Host "  4) VS Code"
Write-Host ""
$choice = Read-Host "Pick [1-4, default 1]"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

$DoDesktop = $false; $DoCode = $false; $DoVSCode = $false
switch ($choice) {
  '1' { $DoDesktop = $true; $DoCode = $true; $DoVSCode = $true }
  '2' { $DoDesktop = $true }
  '3' { $DoCode = $true }
  '4' { $DoVSCode = $true }
  default { Write-Err2 "Invalid choice."; exit 1 }
}

# ---------- Claude Desktop preflight ----------
if ($DoDesktop) {
  Write-Step "Setting up Claude Desktop"
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    Write-Err2 "Node.js is not installed. Claude Desktop needs it to connect to remote MCPs."
    Write-Warn2 "Install Node from https://nodejs.org and re-run this script."
    Write-Warn2 "Skipping Claude Desktop."
    $DoDesktop = $false
  }
}

# ---------- Claude Desktop config ----------
if ($DoDesktop) {
  if (-not (Test-Path $ClaudeDesktopDir)) {
    New-Item -ItemType Directory -Path $ClaudeDesktopDir -Force | Out-Null
  }

  if (-not (Test-Path $ClaudeDesktopConfig)) {
    Write-Ok "Creating new config at $ClaudeDesktopConfig"
    '{}' | Set-Content -Path $ClaudeDesktopConfig -Encoding UTF8
  } else {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$ClaudeDesktopConfig.backup.$stamp"
    Copy-Item -Path $ClaudeDesktopConfig -Destination $backup
    Write-Ok "Backed up existing config to $(Split-Path $backup -Leaf)"
  }

  $raw = (Get-Content -Raw -Path $ClaudeDesktopConfig)
  if ([string]::IsNullOrWhiteSpace($raw)) { $raw = '{}' }
  try {
    $config = $raw | ConvertFrom-Json
  } catch {
    Write-Warn2 "Existing config wasn't valid JSON; starting fresh (backup kept)."
    $config = [PSCustomObject]@{}
  }
  if ($null -eq $config) { $config = [PSCustomObject]@{} }

  if (-not ($config.PSObject.Properties.Name -contains 'mcpServers')) {
    $config | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value ([PSCustomObject]@{})
  }

  $figmaEntry = [PSCustomObject]@{
    command = 'npx'
    args    = @('-y', 'mcp-remote', $FigmaMcpUrl)
  }

  if ($config.mcpServers.PSObject.Properties.Name -contains 'figma') {
    $config.mcpServers.figma = $figmaEntry
  } else {
    $config.mcpServers | Add-Member -MemberType NoteProperty -Name 'figma' -Value $figmaEntry
  }

  $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ClaudeDesktopConfig -Encoding UTF8
  Write-Ok "Claude Desktop configured (existing servers preserved)."
}

# ---------- Claude Code ----------
if ($DoCode) {
  Write-Step "Setting up Claude Code"
  $claude = Get-Command claude -ErrorAction SilentlyContinue
  if (-not $claude) {
    Write-Warn2 "The 'claude' CLI is not installed. Install it from https://claude.com/claude-code and re-run."
  } else {
    $existing = ''
    try { $existing = (& claude mcp list 2>$null) -join "`n" } catch {}
    if ($existing -match '(?m)^\s*figma\b|^\s*figma\s') {
      Write-Ok "Claude Code already has 'figma' configured. Skipping."
    } else {
      $added = $false
      try {
        & claude mcp add --transport http figma $FigmaMcpUrl --scope user 2>$null
        if ($LASTEXITCODE -eq 0) { $added = $true }
      } catch {}
      if ($added) {
        Write-Ok "Added 'figma' to Claude Code (user scope)."
      } else {
        Write-Warn2 "Could not add via --transport http. Trying mcp-remote fallback..."
        try {
          & claude mcp add figma --scope user -- npx -y mcp-remote $FigmaMcpUrl
          if ($LASTEXITCODE -eq 0) {
            Write-Ok "Added 'figma' via mcp-remote fallback."
          } else {
            Write-Err2 "Failed. Run manually: claude mcp add --transport http figma $FigmaMcpUrl --scope user"
          }
        } catch {
          Write-Err2 "Failed. Run manually: claude mcp add --transport http figma $FigmaMcpUrl --scope user"
        }
      }
    }
  }
}

# ---------- VS Code ----------
if ($DoVSCode) {
  Write-Step "Setting up VS Code"

  if (-not (Test-Path $VSCodeUserDir)) {
    New-Item -ItemType Directory -Path $VSCodeUserDir -Force | Out-Null
  }

  if (-not (Test-Path $VSCodeMcpConfig)) {
    Write-Ok "Creating new mcp.json at $VSCodeMcpConfig"
    '{}' | Set-Content -Path $VSCodeMcpConfig -Encoding UTF8
  } else {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$VSCodeMcpConfig.backup.$stamp"
    Copy-Item -Path $VSCodeMcpConfig -Destination $backup
    Write-Ok "Backed up existing VS Code mcp.json to $(Split-Path $backup -Leaf)"
  }

  $rawVs = (Get-Content -Raw -Path $VSCodeMcpConfig)
  if ([string]::IsNullOrWhiteSpace($rawVs)) { $rawVs = '{}' }
  try {
    $vsConfig = $rawVs | ConvertFrom-Json
  } catch {
    Write-Warn2 "Existing VS Code mcp.json wasn't valid JSON; starting fresh (backup kept)."
    $vsConfig = [PSCustomObject]@{}
  }
  if ($null -eq $vsConfig) { $vsConfig = [PSCustomObject]@{} }

  if (-not ($vsConfig.PSObject.Properties.Name -contains 'inputs')) {
    $vsConfig | Add-Member -MemberType NoteProperty -Name 'inputs' -Value @()
  }
  if (-not ($vsConfig.PSObject.Properties.Name -contains 'servers')) {
    $vsConfig | Add-Member -MemberType NoteProperty -Name 'servers' -Value ([PSCustomObject]@{})
  }

  # VS Code takes the HTTP URL directly (no mcp-remote wrapper needed)
  $vsFigmaEntry = [PSCustomObject]@{
    url  = $FigmaMcpUrl
    type = 'http'
  }
  if ($vsConfig.servers.PSObject.Properties.Name -contains 'figma') {
    $vsConfig.servers.figma = $vsFigmaEntry
  } else {
    $vsConfig.servers | Add-Member -MemberType NoteProperty -Name 'figma' -Value $vsFigmaEntry
  }

  $vsConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $VSCodeMcpConfig -Encoding UTF8
  Write-Ok "VS Code configured."
  Write-Host "    In VS Code, open mcp.json and click 'Start' above the figma server entry." -ForegroundColor DarkGray
}

# ---------- restart Claude Desktop ----------
if ($DoDesktop) {
  Write-Step "Restart Claude Desktop so the new config loads"
  if (Prompt-YN "Restart Claude Desktop now?") {
    Get-Process -Name 'Claude' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    $claudePath = @(
      "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
      "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
      "$env:ProgramFiles\Claude\Claude.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($claudePath) {
      Start-Process $claudePath
      Write-Ok "Claude restarted."
    } else {
      Write-Warn2 "Couldn't find Claude.exe automatically. Open it manually."
    }
  }
}

# ---------- done ----------
Write-Host ""
Write-Host "All set." -ForegroundColor Green
Write-Host ""
Write-Host "Authenticate: when you first use a Figma tool, a browser window"
Write-Host "will open. Sign in to Figma and click Allow."
Write-Host ""
Write-Host "Test it: in Claude, type  List MCP tools"
Write-Host "You should see Figma tools like get_design_context, get_screenshot, get_metadata."
Write-Host ""
