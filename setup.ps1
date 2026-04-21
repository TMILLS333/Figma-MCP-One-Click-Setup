# Figma MCP - One-Click Setup (Windows PowerShell)
#
# Adds the official Figma MCP (https://mcp.figma.com/mcp, OAuth) to:
#   - Claude Desktop
#   - Claude Code
#   - Cowork (guided: Figma is an official connector in Cowork's registry)
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
$FigmaMcpUrl         = 'https://mcp.figma.com/mcp'

# ---------- header ----------
Clear-Host
Write-Host "Figma MCP - One-Click Setup" -ForegroundColor White
Write-Host "Connects Figma to Claude Desktop, Claude Code, and Cowork." -ForegroundColor DarkGray
Write-Host ""

# ---------- which clients? ----------
Write-Step "Which clients do you want to set up?"
Write-Host "  1) All three - Claude Desktop, Claude Code, and Cowork (recommended)"
Write-Host "  2) Claude Desktop only"
Write-Host "  3) Claude Code only"
Write-Host "  4) Cowork only (just show me the two clicks)"
Write-Host "  5) Custom - pick a combo"
Write-Host ""
$choice = Read-Host "Pick [1-5, default 1]"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

$DoDesktop = $false; $DoCode = $false; $DoCowork = $false
switch ($choice) {
  '1' { $DoDesktop = $true; $DoCode = $true; $DoCowork = $true }
  '2' { $DoDesktop = $true }
  '3' { $DoCode = $true }
  '4' { $DoCowork = $true }
  '5' {
    $DoDesktop = Prompt-YN "Claude Desktop?"
    $DoCode    = Prompt-YN "Claude Code?"
    $DoCowork  = Prompt-YN "Cowork?"
  }
  default { Write-Err2 "Invalid choice."; exit 1 }
}

# ---------- Claude Desktop ----------
if ($DoDesktop) {
  Write-Step "Setting up Claude Desktop"

  # Node check - needed for npx mcp-remote
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    Write-Err2 "Node.js is not installed. Claude Desktop needs it to connect to remote MCPs."
    Write-Warn2 "Install Node from https://nodejs.org and re-run this script."
    Write-Warn2 "Skipping Claude Desktop."
    $DoDesktop = $false
  }
}

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

  # Load, merge, save
  $raw = (Get-Content -Raw -Path $ClaudeDesktopConfig)
  if ([string]::IsNullOrWhiteSpace($raw)) { $raw = '{}' }
  try {
    $config = $raw | ConvertFrom-Json
  } catch {
    Write-Warn2 "Existing config wasn't valid JSON; starting fresh (backup kept)."
    $config = [PSCustomObject]@{}
  }
  if ($null -eq $config) { $config = [PSCustomObject]@{} }

  # Ensure mcpServers object exists
  if (-not ($config.PSObject.Properties.Name -contains 'mcpServers')) {
    $config | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value ([PSCustomObject]@{})
  }

  # Build the figma entry
  $figmaEntry = [PSCustomObject]@{
    command = 'npx'
    args    = @('-y', 'mcp-remote', $FigmaMcpUrl)
  }

  # Add or overwrite 'figma'
  if ($config.mcpServers.PSObject.Properties.Name -contains 'figma') {
    $config.mcpServers.figma = $figmaEntry
  } else {
    $config.mcpServers | Add-Member -MemberType NoteProperty -Name 'figma' -Value $figmaEntry
  }

  # Write back (pretty)
  $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ClaudeDesktopConfig -Encoding UTF8
  Write-Ok "Added 'figma' to mcpServers (existing servers preserved)."
  Write-Ok "Claude Desktop configured."
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

# ---------- Cowork (guided - 2 clicks) ----------
if ($DoCowork) {
  Write-Step "Setting up Cowork"
  Write-Host "  Figma is an official Cowork connector - this part is 2 clicks, no file editing." -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "  In Claude:" -ForegroundColor White
  Write-Host "    1. Open Claude Desktop and click the Cowork tab."
  Write-Host "    2. Click Customize in the left sidebar."
  Write-Host "    3. Click Browse connectors (or Browse plugins)."
  Write-Host "    4. Find Figma in the list and click Connect."
  Write-Host "    5. Sign in to Figma, click Allow. Done."
  Write-Host ""

  if (Prompt-YN "Open Claude now?") {
    $claudePath = @(
      "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe",
      "$env:LOCALAPPDATA\Programs\Claude\Claude.exe",
      "$env:ProgramFiles\Claude\Claude.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($claudePath) {
      Start-Process $claudePath
      Write-Ok "Claude launched. Click the Cowork tab -> Customize -> Figma -> Connect."
    } else {
      Write-Warn2 "Couldn't find Claude.exe automatically. Open it from the Start menu."
    }
  }
}

# ---------- restart Claude Desktop so config loads ----------
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
Write-Host "Test it: in Claude, type  List MCP tools"
Write-Host "You should see Figma tools like get_design_context, get_screenshot, get_metadata."
Write-Host ""
Write-Host "Part of How to Platypus - weareplatypus.com" -ForegroundColor DarkGray
