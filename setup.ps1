# Official Figma MCP Server — Windows Setup
# Configures the remote (mcp.figma.com) or desktop (local) server
# No external dependencies — uses native PowerShell JSON handling
# Usage: powershell -ExecutionPolicy Bypass -File .\setup.ps1
#        powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Force
param([switch]$Force)

# ============================================================
# Configuration
# ============================================================
$ErrorActionPreference = "Continue"

if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

# Server URLs
$script:RemoteUrl  = "https://mcp.figma.com/mcp"
$script:DesktopUrl = "http://127.0.0.1:3845/mcp"

# Config file paths
$script:ConfigFiles = @(
    "$env:APPDATA\Claude\claude_desktop_config.json",
    "$env:USERPROFILE\.cursor\mcp.json",
    "$env:USERPROFILE\.claude.json"
)
$script:VSCodeMcpConfig = "$env:APPDATA\Code\User\mcp.json"

# State
$script:ServerName = ""
$script:ServerUrl  = ""
$script:ServerType = ""

# ============================================================
# JSON Helpers (native PowerShell — no external dependencies)
# ============================================================

function Test-HasFigmaConfig {
    param([string]$ConfigPath)
    if (-not (Test-Path $ConfigPath)) { return $false }
    $raw = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
    return ($raw -match '"figma"|"figma-desktop"')
}

function Get-ServerName {
    param([string]$ConfigPath)
    if (-not (Test-Path $ConfigPath)) { return "" }
    $raw = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
    if ($raw -match '"figma-desktop"') { return "figma-desktop" }
    if ($raw -match '"figma"') { return "figma" }
    return ""
}

function Get-ConfiguredClients {
    $clients = @()
    if (Test-HasFigmaConfig "$env:APPDATA\Claude\claude_desktop_config.json") { $clients += "Claude Desktop" }
    if (Test-HasFigmaConfig "$env:USERPROFILE\.claude.json") { $clients += "Claude Code" }
    if (Test-HasFigmaConfig "$env:USERPROFILE\.cursor\mcp.json") { $clients += "Cursor" }
    if (Test-HasFigmaConfig $script:VSCodeMcpConfig) { $clients += "VS Code" }
    return $clients
}

function Get-CurrentMode {
    foreach ($cf in ($script:ConfigFiles + $script:VSCodeMcpConfig)) {
        $name = Get-ServerName $cf
        if ($name -eq "figma-desktop") { return "desktop" }
        if ($name -eq "figma") { return "remote" }
    }
    return ""
}

# Read JSON, merge entry, write back — pure PowerShell
function Write-McpServersConfig {
    param([string]$FilePath, [string]$Name, [string]$Url)
    $dir = Split-Path -Parent $FilePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $config = @{}
    if (Test-Path $FilePath) {
        try {
            $raw = Get-Content $FilePath -Raw -ErrorAction Stop
            $config = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Host "  $FilePath has invalid JSON - fix it manually then re-run" -ForegroundColor Red
            return
        }
    }

    # Ensure mcpServers exists as a hashtable
    if (-not $config.mcpServers) {
        $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([ordered]@{}) -Force
    }

    # Convert PSObject to ordered hashtable for easy manipulation
    $servers = [ordered]@{}
    $config.mcpServers.PSObject.Properties | ForEach-Object {
        if ($_.Name -ne "figma" -and $_.Name -ne "figma-desktop") {
            $servers[$_.Name] = $_.Value
        }
    }
    $servers[$Name] = [ordered]@{ url = $Url }

    $config.mcpServers = $servers
    $config | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding UTF8
    Write-Host "  Configured: $FilePath" -ForegroundColor Green
}

# VS Code uses "servers" not "mcpServers", plus "type": "http"
function Write-VSCodeConfig {
    param([string]$Name, [string]$Url)
    $dir = Split-Path -Parent $script:VSCodeMcpConfig
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $config = @{}
    if (Test-Path $script:VSCodeMcpConfig) {
        try {
            $raw = Get-Content $script:VSCodeMcpConfig -Raw -ErrorAction Stop
            $config = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Host "  $($script:VSCodeMcpConfig) has invalid JSON - fix it manually" -ForegroundColor Red
            return
        }
    }

    if (-not $config.inputs) {
        $config | Add-Member -NotePropertyName "inputs" -NotePropertyValue @() -Force
    }
    if (-not $config.servers) {
        $config | Add-Member -NotePropertyName "servers" -NotePropertyValue ([ordered]@{}) -Force
    }

    $servers = [ordered]@{}
    $config.servers.PSObject.Properties | ForEach-Object {
        if ($_.Name -ne "figma" -and $_.Name -ne "figma-desktop") {
            $servers[$_.Name] = $_.Value
        }
    }
    $servers[$Name] = [ordered]@{ url = $Url; type = "http" }

    $config.servers = $servers
    $config | ConvertTo-Json -Depth 10 | Set-Content $script:VSCodeMcpConfig -Encoding UTF8
    Write-Host "  VS Code configured" -ForegroundColor Green
}

# Configure Claude Code via CLI
function Set-ClaudeCode {
    param([string]$Name, [string]$Url)
    $claudeCli = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCli) {
        & claude mcp remove figma --scope user 2>&1 | Out-Null
        & claude mcp remove figma-desktop --scope user 2>&1 | Out-Null
        & claude mcp add --transport http --scope user "$Name" "$Url" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Claude Code configured (via CLI)" -ForegroundColor Green
            return
        }
        Write-Host "  'claude mcp add' failed - writing config directly" -ForegroundColor Yellow
    }
    Write-McpServersConfig "$env:USERPROFILE\.claude.json" $Name $Url
}

# Prompt for client selection
function Update-ClientConfigs {
    Write-Host "  1) Claude Desktop  2) Claude Code  3) Cursor  4) VS Code  5) All  6) Skip"
    $cc = Read-Host "  Choose [1-6]"
    switch ($cc) {
        "1" { Write-McpServersConfig "$env:APPDATA\Claude\claude_desktop_config.json" $script:ServerName $script:ServerUrl }
        "2" { Set-ClaudeCode $script:ServerName $script:ServerUrl }
        "3" { Write-McpServersConfig "$env:USERPROFILE\.cursor\mcp.json" $script:ServerName $script:ServerUrl }
        "4" { Write-VSCodeConfig $script:ServerName $script:ServerUrl }
        "5" {
            Write-McpServersConfig "$env:APPDATA\Claude\claude_desktop_config.json" $script:ServerName $script:ServerUrl
            Set-ClaudeCode $script:ServerName $script:ServerUrl
            Write-McpServersConfig "$env:USERPROFILE\.cursor\mcp.json" $script:ServerName $script:ServerUrl
            Write-VSCodeConfig $script:ServerName $script:ServerUrl
        }
        "6" { Write-Host "  Skipped" -ForegroundColor Yellow }
        default { Write-Host "  Skipped" -ForegroundColor Yellow }
    }
}

# Restart Claude Desktop (Windows)
function Restart-Claude {
    $claudeProcs = Get-Process -Name "claude" -ErrorAction SilentlyContinue
    if ($claudeProcs) {
        Write-Host "  Restarting Claude Desktop..." -ForegroundColor DarkGray
        $claudeProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $claudeExe = "$env:LOCALAPPDATA\Programs\claude-desktop\Claude.exe"
        if (-not (Test-Path $claudeExe)) {
            $claudeExe = "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe"
        }
        if (Test-Path $claudeExe) {
            Start-Process $claudeExe
            Write-Host "  Claude Desktop restarted" -ForegroundColor Green
        } else {
            Write-Host "  Claude Desktop stopped - please reopen it manually" -ForegroundColor Yellow
        }
    }
}

# ============================================================
# Banner
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Official Figma MCP Server - Setup     " -ForegroundColor Cyan
Write-Host "  Remote  |  Desktop                    " -ForegroundColor DarkGray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Smart re-run detection
# ============================================================
if (-not $Force) {
    $currentMode = Get-CurrentMode
    $configuredClients = Get-ConfiguredClients

    if (-not [string]::IsNullOrEmpty($currentMode) -and $configuredClients.Count -gt 0) {
        Write-Host "  Setup is already complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Current settings:" -ForegroundColor White
        Write-Host "    Mode:     $currentMode" -ForegroundColor DarkGray
        Write-Host "    Clients:  $($configuredClients -join ', ')" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  What would you like to do?" -ForegroundColor White
        Write-Host "    1) Switch mode (remote <-> desktop)"
        Write-Host "    2) Add/change client"
        Write-Host "    3) Full re-setup (same as -Force)"
        Write-Host "    4) Exit - nothing to change"
        $choice = Read-Host "  Choose [1-4]"

        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "  Switch Server Mode" -ForegroundColor Cyan
                if ($currentMode -eq "remote") {
                    Write-Host "  Switching from remote to desktop..."
                    $script:ServerName = "figma-desktop"
                    $script:ServerUrl  = $script:DesktopUrl
                    $script:ServerType = "desktop"
                } else {
                    Write-Host "  Switching from desktop to remote..."
                    $script:ServerName = "figma"
                    $script:ServerUrl  = $script:RemoteUrl
                    $script:ServerType = "remote"
                }
                foreach ($cf in $script:ConfigFiles) {
                    if (Test-HasFigmaConfig $cf) {
                        if ($cf -eq "$env:USERPROFILE\.claude.json") {
                            Set-ClaudeCode $script:ServerName $script:ServerUrl
                        } else {
                            Write-McpServersConfig $cf $script:ServerName $script:ServerUrl
                        }
                    }
                }
                if (Test-HasFigmaConfig $script:VSCodeMcpConfig) {
                    Write-VSCodeConfig $script:ServerName $script:ServerUrl
                }
                Restart-Claude
                Write-Host ""
                Write-Host "  Switched to $($script:ServerType) mode!" -ForegroundColor Green
                if ($script:ServerType -eq "desktop") {
                    Write-Host "  Remember: Open Figma Desktop > Dev Mode > Enable desktop MCP server" -ForegroundColor Yellow
                }
                exit 0
            }
            "2" {
                Write-Host ""
                Write-Host "  Add/Change Client" -ForegroundColor Cyan
                if ($currentMode -eq "remote") {
                    $script:ServerName = "figma"
                    $script:ServerUrl  = $script:RemoteUrl
                    $script:ServerType = "remote"
                } else {
                    $script:ServerName = "figma-desktop"
                    $script:ServerUrl  = $script:DesktopUrl
                    $script:ServerType = "desktop"
                }
                Update-ClientConfigs
                Restart-Claude
                Write-Host ""
                Write-Host "  Client config updated!" -ForegroundColor Green
                exit 0
            }
            "3" {
                Write-Host ""
                Write-Host "  Running full setup..." -ForegroundColor Cyan
                # Fall through
            }
            default {
                Write-Host ""
                Write-Host "  No changes. Bye!" -ForegroundColor Green
                exit 0
            }
        }
    }
}

# ============================================================
# Step 1 - Choose server mode
# ============================================================
Write-Host "Step 1/2 - Choose server mode" -ForegroundColor White
Write-Host ""
Write-Host "  1) Remote  - mcp.figma.com (OAuth, no desktop app needed)"
Write-Host "     Supports: code generation, design context, send UI to Figma"
Write-Host ""
Write-Host "  2) Desktop - Figma Desktop app (local server on port 3845)"
Write-Host "     Supports: code generation, design context, selection-based prompts"
Write-Host ""
$modeChoice = Read-Host "  Choose [1-2] (default: 1)"

switch ($modeChoice) {
    "2" {
        $script:ServerName = "figma-desktop"
        $script:ServerUrl  = $script:DesktopUrl
        $script:ServerType = "desktop"
        Write-Host ""
        Write-Host "  Desktop mode selected" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Important: Before using the MCP server, you must:" -ForegroundColor Yellow
        Write-Host "    1. Open the Figma Desktop app (latest version)"
        Write-Host "    2. Open a Figma Design file"
        Write-Host "    3. Toggle to Dev Mode (Shift+D)"
        Write-Host "    4. Click 'Enable desktop MCP server' in the inspect panel"
        Write-Host ""
        Write-Host "  The server runs at http://127.0.0.1:3845/mcp" -ForegroundColor DarkGray
    }
    default {
        $script:ServerName = "figma"
        $script:ServerUrl  = $script:RemoteUrl
        $script:ServerType = "remote"
        Write-Host ""
        Write-Host "  Remote mode selected" -ForegroundColor Green
        Write-Host "  You'll authenticate via browser when first connecting" -ForegroundColor DarkGray
    }
}

# ============================================================
# Step 2 - Configure client(s)
# ============================================================
Write-Host ""
Write-Host "Step 2/2 - Configure your AI client" -ForegroundColor White
Write-Host ""
Update-ClientConfigs

# ============================================================
# Authentication instructions
# ============================================================
if ($script:ServerType -eq "remote") {
    Write-Host ""
    Write-Host "  Next: Authenticate" -ForegroundColor White
    Write-Host ""
    Write-Host "  When you first use the Figma MCP server in your client,"
    Write-Host "  you'll be prompted to authenticate via your browser."
    Write-Host ""
    Write-Host "  For Claude Code:" -ForegroundColor Cyan
    Write-Host "    Type /mcp > select figma > Authenticate"
    Write-Host "    Click 'Allow Access' in the browser"
    Write-Host ""
    Write-Host "  For Cursor:" -ForegroundColor Cyan
    Write-Host "    Click 'Connect' next to Figma in MCP settings"
    Write-Host "    Click 'Allow Access' in the browser"
    Write-Host ""
    Write-Host "  For VS Code:" -ForegroundColor Cyan
    Write-Host "    Click 'Start' above the server name in mcp.json"
    Write-Host "    Click 'Allow Access' in the browser"
    Write-Host ""
}

# ============================================================
# Done
# ============================================================
Restart-Claude
Write-Host ""
Write-Host "  ======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host ""
if ($script:ServerType -eq "remote") {
    Write-Host "  To verify, try prompting:"
    Write-Host "    'Get the design context from <paste a Figma link>'" -ForegroundColor DarkGray
} else {
    Write-Host "  Make sure Figma Desktop is running with Dev Mode enabled,"
    Write-Host "  then try prompting:"
    Write-Host "    'Implement my current selection'" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  ======================================" -ForegroundColor Green
Write-Host ""
