<#
.SYNOPSIS
    Automated dev environment setup script for VS Code, tooling, and project configurations.

.DESCRIPTION
    Installs global VS Code settings, recommended extensions, and essential project
    configuration files (.prettierrc, .gitattributes, .gitignore, oxlint.config.mts, .vscode/settings.json).
    Supports all VS Code variants (Stable, Insiders, VSCodium, Cursor, code-oss) and both
    user-level (default) and system-level installs. Automatically switches to PowerShell Core
    (pwsh) if available.

.PARAMETER TsConfig
    Optional TypeScript template to configure as tsconfig.json: 'none' (default), 'backend', or 'frontend'.

.PARAMETER BaseUrl
    Base URL for remote configuration files. Defaults to xcfio/settings main branch.

.PARAMETER Editor
    VS Code variant to target. Choices: 'code' (default), 'code-insiders', 'codium', 'cursor', 'code-oss'.
    The script also auto-detects the first available CLI when the specified editor is not on PATH.

.PARAMETER Scope
    Install scope for VS Code settings: 'User' (default, roaming profile / home dir) or
    'System' (machine-wide ProgramData / /etc/vscode directory). Requires elevated privileges
    when set to 'System'.

.PARAMETER SkipSettings
    Skip updating global VS Code settings.

.PARAMETER SkipExtensions
    Skip installing VS Code extensions.

.PARAMETER SkipConfigs
    Skip downloading project configuration files to the current directory.

.PARAMETER Force
    Force reinstalling extensions and overwriting files without skipping.

.PARAMETER NoPwsh
    Prevent relaunching under PowerShell Core (pwsh) when running under Windows PowerShell.

.EXAMPLE
    irm https://raw.githubusercontent.com/xcfio/settings/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1 -TsConfig backend

.EXAMPLE
    .\install.ps1 -Editor code-insiders -Scope System -Force

.EXAMPLE
    .\install.ps1 -Editor codium -SkipExtensions
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("none", "backend", "frontend")]
    [string]$TsConfig = "none",

    [string]$BaseUrl = "https://raw.githubusercontent.com/xcfio/settings/main",

    [ValidateSet("code", "code-insiders", "codium", "cursor", "code-oss")]
    [string]$Editor = "code",

    [ValidateSet("User", "System", "Auto")]
    [string]$Scope = "Auto",

    [switch]$SkipSettings,
    [switch]$SkipExtensions,
    [switch]$SkipConfigs,
    [switch]$Force,
    [switch]$NoPwsh
)

$ErrorActionPreference = "Stop"

# -------------------------------------------------------------------------
# Step 0: Ensure PowerShell Core (pwsh) if available
# -------------------------------------------------------------------------
if ($PSVersionTable.PSEdition -ne "Core" -and -not $NoPwsh) {
    $pwshCandidates = @(
        (Get-Command pwsh.exe, pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\PowerShell\pwsh.exe",
        "$env:LOCALAPPDATA\Programs\PowerShell\pwsh.exe"
    )
    $pwshBin = $pwshCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($pwshBin) {
        Write-Host "[*] PowerShell Core detected at '$pwshBin'. Switching to pwsh..." -ForegroundColor Cyan

        $scriptPath = $PSCommandPath
        if (-not $scriptPath -and $MyInvocation.MyCommand.Path) {
            $scriptPath = $MyInvocation.MyCommand.Path
        }
        if (-not $scriptPath -and (Test-Path ".\install.ps1")) {
            $scriptPath = (Resolve-Path ".\install.ps1").Path
        }

        # Build forward arguments from bound parameters
        $forwardArgs = @()
        foreach ($key in $PSBoundParameters.Keys) {
            if ($key -eq "NoPwsh") { continue }
            $val = $PSBoundParameters[$key]
            if ($val -is [switch]) {
                if ($val.IsPresent) { $forwardArgs += "-$key" }
            } else {
                $forwardArgs += "-$key"
                $forwardArgs += "$val"
            }
        }
        if ($args) {
            $forwardArgs += $args
        }

        if ($scriptPath) {
            & $pwshBin -NoProfile -ExecutionPolicy Bypass -File $scriptPath @forwardArgs
            exit $LASTEXITCODE
        } else {
            # Running via piped iex (e.g., irm https://.../install.ps1 | iex)
            $remoteCmd = "Invoke-RestMethod '$BaseUrl/install.ps1' | Invoke-Expression"
            & $pwshBin -NoProfile -ExecutionPolicy Bypass -Command $remoteCmd
            return
        }
    } else {
        Write-Host "[-] PowerShell Core (pwsh) not found. Continuing with Windows PowerShell $($PSVersionTable.PSVersion)..." -ForegroundColor Yellow
    }
}

# Ensure TLS 1.2 on Windows PowerShell 5.1
if ($PSVersionTable.PSEdition -ne "Core") {
    if ([Net.ServicePointManager]::SecurityProtocol -notmatch "Tls12") {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
}

# -------------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------------
function Download-File {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutPath
    )

    $parentDir = Split-Path -Parent $OutPath
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if ($PSVersionTable.PSEdition -eq "Core") {
        Invoke-WebRequest -Uri $Url -OutFile $OutPath
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing
    }
}

function Get-WebContent {
    param(
        [Parameter(Mandatory = $true)][string]$Url
    )

    if ($PSVersionTable.PSEdition -eq "Core") {
        return (Invoke-WebRequest -Uri $Url).Content
    } else {
        return (Invoke-WebRequest -Uri $Url -UseBasicParsing).Content
    }
}

# Resolve the CLI command for the selected (or auto-detected) VS Code variant.
# Returns a hashtable: @{ Cmd = <string>; Label = <string> }
function Resolve-VSCodeCLI {
    param([string]$PreferredEditor)

    # Ordered candidate list per variant (CLI name -> human label)
    $variantMap = [ordered]@{
        "code"          = @{ Cmds = @("code");          Label = "VS Code Stable"   }
        "code-insiders" = @{ Cmds = @("code-insiders"); Label = "VS Code Insiders" }
        "codium"        = @{ Cmds = @("codium");        Label = "VSCodium"         }
        "cursor"        = @{ Cmds = @("cursor");        Label = "Cursor"           }
        "code-oss"      = @{ Cmds = @("code-oss");      Label = "Code OSS"         }
    }

    # Try the preferred editor first
    $entry = $variantMap[$PreferredEditor]
    if ($entry) {
        foreach ($cmd in $entry.Cmds) {
            $found = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($found) { return @{ Cmd = $cmd; Label = $entry.Label } }
        }
    }

    # Fall back: try every other variant in order
    foreach ($key in $variantMap.Keys) {
        if ($key -eq $PreferredEditor) { continue }
        $fb = $variantMap[$key]
        foreach ($cmd in $fb.Cmds) {
            $found = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($found) { return @{ Cmd = $cmd; Label = $fb.Label } }
        }
    }

    return $null
}

# Resolve the settings.json path for the given editor variant and scope.
# Scope 'User'   -> per-user roaming/home config dir
# Scope 'System' -> machine-wide config dir (requires admin on Windows)
# Scope 'Auto'   -> probes System then User; returns the first path that exists,
#                   falling back to the User path if neither is found yet.
function Get-VSCodeSettingsPath {
    param(
        [string]$EditorVariant = "code",
        [string]$InstallScope  = "Auto"
    )

    # Map variant -> subdirectory name used inside the config root
    $dirMap = @{
        "code"          = "Code"
        "code-insiders" = "Code - Insiders"
        "codium"        = "VSCodium"
        "cursor"        = "Cursor"
        "code-oss"      = "code-oss"
    }
    $dirName = if ($dirMap.ContainsKey($EditorVariant)) { $dirMap[$EditorVariant] } else { "Code" }

    # Build the concrete path for a given explicit scope
    function Resolve-ScopedPath([string]$Scope) {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            if ($Scope -eq "System") {
                return (Join-Path $env:ProgramData "$dirName\User\settings.json")
            } else {
                return (Join-Path $env:APPDATA "$dirName\User\settings.json")
            }
        } elseif ($IsMacOS -or ($env:OSTYPE -match "darwin")) {
            if ($Scope -eq "System") {
                return "/Library/Application Support/$dirName/User/settings.json"
            } else {
                return (Join-Path $HOME "Library/Application Support/$dirName/User/settings.json")
            }
        } else {
            # Linux / WSL
            if ($Scope -eq "System") {
                return "/etc/vscode/$dirName/settings.json"
            } else {
                $configDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { (Join-Path $HOME ".config") }
                return (Join-Path $configDir "$dirName/User/settings.json")
            }
        }
    }

    if ($InstallScope -eq "Auto") {
        # Probe System first, then User; return whichever settings.json already exists.
        # If neither exists yet, fall back to the User path (install will create it).
        $systemPath = Resolve-ScopedPath "System"
        $userPath   = Resolve-ScopedPath "User"
        if (Test-Path $systemPath) { return $systemPath }
        if (Test-Path $userPath)   { return $userPath   }
        return $userPath
    }

    return (Resolve-ScopedPath $InstallScope)
}

# -------------------------------------------------------------------------
# Banner
# -------------------------------------------------------------------------
$shellInfo = "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
$targetOs  = if ($IsWindows -or $env:OS -eq "Windows_NT") { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" }

# Map variant to display label (before CLI resolution)
$editorLabelMap = @{
    "code"          = "VS Code Stable"
    "code-insiders" = "VS Code Insiders"
    "codium"        = "VSCodium"
    "cursor"        = "Cursor"
    "code-oss"      = "Code OSS"
}
$editorLabel = if ($editorLabelMap.ContainsKey($Editor)) { $editorLabelMap[$Editor] } else { $Editor }

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Dev Environment Setup (xcfio/settings)" -ForegroundColor Cyan
Write-Host "  Shell  : $shellInfo" -ForegroundColor DarkGray
Write-Host "  OS     : $targetOs" -ForegroundColor DarkGray
Write-Host "  Editor : $editorLabel" -ForegroundColor DarkGray
Write-Host "  Scope  : $(if ($Scope -eq 'Auto') { 'Auto (System → User)' } else { $Scope })" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Warn early when system scope may be involved without elevation (Windows)
$mightUseSystem = ($Scope -eq "System") -or ($Scope -eq "Auto")
if ($mightUseSystem -and ($IsWindows -or $env:OS -eq "Windows_NT")) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin -and $Scope -eq "System") {
        Write-Host "[!] WARNING: '-Scope System' requires Administrator privileges on Windows." -ForegroundColor Yellow
        Write-Host "    Settings may fail to write. Re-run as Administrator for system-wide install." -ForegroundColor DarkGray
        Write-Host ""
    }
}


# -------------------------------------------------------------------------
# Step 1: Global VS Code Settings
# -------------------------------------------------------------------------
if (-not $SkipSettings) {
    Write-Host "[1/4] Global VS Code Settings" -ForegroundColor Cyan
    $settingsPath = Get-VSCodeSettingsPath -EditorVariant $Editor -InstallScope $Scope
    $settingsDir  = Split-Path -Parent $settingsPath

    try {
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }

        if (Test-Path $settingsPath) {
            $backupPath = "$settingsPath.bak"
            Copy-Item -Path $settingsPath -Destination $backupPath -Force
            Write-Host "  [+] Backed up existing settings to $backupPath" -ForegroundColor DarkGray
        }

        Download-File -Url "$BaseUrl/settings.json" -OutPath $settingsPath
        Write-Host "  [+] Global VS Code settings installed: $settingsPath" -ForegroundColor Green
    } catch {
        Write-Host "  [x] Failed to install VS Code settings: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[1/4] Global VS Code Settings: SKIPPED (-SkipSettings)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Step 2: VS Code Extensions
# -------------------------------------------------------------------------
if (-not $SkipExtensions) {
    Write-Host "`n[2/4] VS Code Extensions" -ForegroundColor Cyan

    $cliInfo = Resolve-VSCodeCLI -PreferredEditor $Editor

    if (-not $cliInfo) {
        Write-Host "  [!] No VS Code CLI found on PATH. Searched: code, code-insiders, codium, cursor, code-oss." -ForegroundColor Yellow
        Write-Host "      Tip: Open VS Code > Ctrl+Shift+P > 'Shell Command: Install ''code'' command in PATH'" -ForegroundColor DarkGray
    } else {
        $codeCmd  = $cliInfo.Cmd
        $codeLabel = $cliInfo.Label

        # Warn if a fallback was used
        if ($codeCmd -ne $Editor) {
            Write-Host "  [!] '$Editor' not found; using '$codeCmd' ($codeLabel) instead." -ForegroundColor Yellow
        } else {
            Write-Host "  [i] Using CLI: $codeCmd ($codeLabel)" -ForegroundColor DarkGray
        }

        try {
            $extUrl  = "$BaseUrl/extensions.json"
            $rawJson = Get-WebContent -Url $extUrl
            # Strip JS-style comments before parsing
            $cleanJson      = $rawJson -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
            $recommendations = ($cleanJson | ConvertFrom-Json).recommendations

            if ($recommendations -and $recommendations.Count -gt 0) {
                # Read currently installed extensions
                $installedExtensions = @(& $codeCmd --list-extensions 2>$null)
                $installedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($item in $installedExtensions) {
                    if ($item -and $item.Trim()) { [void]$installedSet.Add($item.Trim()) }
                }

                $total         = $recommendations.Count
                $curr          = 0
                $installedCount = 0
                $skippedCount  = 0

                foreach ($ext in $recommendations) {
                    $curr++
                    $extName = $ext.ToString().Trim()
                    if (-not $extName) { continue }

                    if (-not $Force -and $installedSet.Contains($extName)) {
                        Write-Host "  [$curr/$total] [=] Already installed: $extName" -ForegroundColor DarkGray
                        $skippedCount++
                    } else {
                        Write-Host "  [$curr/$total] [+] Installing $extName..." -ForegroundColor Cyan
                        & $codeCmd --install-extension $extName --force | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  [$curr/$total] [v] Installed: $extName" -ForegroundColor Green
                            $installedCount++
                        } else {
                            Write-Host "  [$curr/$total] [x] Failed: $extName" -ForegroundColor Red
                        }
                    }
                }
                Write-Host "  [+] Summary: $total extensions ($installedCount installed/updated, $skippedCount up to date)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [x] Failed to process extensions: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`n[2/4] VS Code Extensions: SKIPPED (-SkipExtensions)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Step 3: Project Configuration Files (Current Directory)
# -------------------------------------------------------------------------
if (-not $SkipConfigs) {
    Write-Host "`n[3/4] Project Configuration Files" -ForegroundColor Cyan
    $projectFiles = @(
        ".prettierrc",
        ".gitattributes",
        ".gitignore",
        "oxlint.config.mts"
    )

    foreach ($file in $projectFiles) {
        $dest = Join-Path (Get-Location) $file
        try {
            Download-File -Url "$BaseUrl/$file" -OutPath $dest
            Write-Host "  [+] Downloaded: $file" -ForegroundColor Green
        } catch {
            Write-Host "  [x] Failed to download $file : $_" -ForegroundColor Red
        }
    }

    # Workspace .vscode/settings.json override (points Oxc extension to oxlint.config.mts)
    $vscodeWorkspaceDir      = Join-Path (Get-Location) ".vscode"
    $vscodeWorkspaceSettings = Join-Path $vscodeWorkspaceDir "settings.json"

    try {
        if (-not (Test-Path $vscodeWorkspaceDir)) {
            New-Item -ItemType Directory -Path $vscodeWorkspaceDir -Force | Out-Null
        }

        if (Test-Path $vscodeWorkspaceSettings) {
            # Preserve existing workspace settings while ensuring oxc.configPath is configured
            try {
                $existingContent    = Get-Content $vscodeWorkspaceSettings -Raw
                $cleanWorkspaceJson = $existingContent -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
                $workspaceObj       = $cleanWorkspaceJson | ConvertFrom-Json
                $workspaceObj | Add-Member -NotePropertyName "oxc.configPath" -NotePropertyValue "oxlint.config.mts" -Force
                $updatedJson = $workspaceObj | ConvertTo-Json -Depth 10
                $utf8NoBom   = [System.Text.UTF8Encoding]::new($false)
                [System.IO.File]::WriteAllText($vscodeWorkspaceSettings, $updatedJson + "`n", $utf8NoBom)
                Write-Host "  [+] Configured oxc.configPath in existing .vscode/settings.json" -ForegroundColor Green
            } catch {
                # Fallback to direct download
                Download-File -Url "$BaseUrl/.vscode/settings.json" -OutPath $vscodeWorkspaceSettings
                Write-Host "  [+] Downloaded: .vscode/settings.json" -ForegroundColor Green
            }
        } else {
            Download-File -Url "$BaseUrl/.vscode/settings.json" -OutPath $vscodeWorkspaceSettings
            Write-Host "  [+] Downloaded: .vscode/settings.json" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [x] Failed to configure .vscode/settings.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`n[3/4] Project Configuration Files: SKIPPED (-SkipConfigs)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Step 4: Optional TypeScript Configuration
# -------------------------------------------------------------------------
Write-Host "`n[4/4] TypeScript Configuration" -ForegroundColor Cyan
$tsconfigDest = Join-Path (Get-Location) "tsconfig.json"

if ($TsConfig -eq "backend") {
    try {
        if (Test-Path $tsconfigDest) {
            Copy-Item -Path $tsconfigDest -Destination "$tsconfigDest.bak" -Force
            Write-Host "  [+] Backed up existing tsconfig.json to tsconfig.json.bak" -ForegroundColor DarkGray
        }
        Download-File -Url "$BaseUrl/tsconfig-backend.json" -OutPath $tsconfigDest
        Write-Host "  [+] Configured TypeScript backend (Node.js/NodeNext): tsconfig.json" -ForegroundColor Green
    } catch {
        Write-Host "  [x] Failed to download backend tsconfig: $_" -ForegroundColor Red
    }
} elseif ($TsConfig -eq "frontend") {
    try {
        if (Test-Path $tsconfigDest) {
            Copy-Item -Path $tsconfigDest -Destination "$tsconfigDest.bak" -Force
            Write-Host "  [+] Backed up existing tsconfig.json to tsconfig.json.bak" -ForegroundColor DarkGray
        }
        Download-File -Url "$BaseUrl/tsconfig-frontend.json" -OutPath $tsconfigDest
        Write-Host "  [+] Configured TypeScript frontend (React/DOM): tsconfig.json" -ForegroundColor Green
    } catch {
        Write-Host "  [x] Failed to download frontend tsconfig: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  [-] No tsconfig template selected." -ForegroundColor DarkGray
    Write-Host "      Tip: Re-run with '-TsConfig backend' or '-TsConfig frontend' to install tsconfig.json" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Summary & Next Steps
# -------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Setup completed successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps for your project:" -ForegroundColor Cyan
Write-Host "  1. Install recommended dev dependencies with pnpm:" -ForegroundColor White
Write-Host "     pnpm add -D oxlint oxlint-plugin-eslint oxlint-tsgolint prettier typescript turbo lefthook commitlint @commitlint/config-conventional @commitlint/format @commitlint/types" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Remember to run project scripts via node:" -ForegroundColor White
Write-Host "     node --run dev" -ForegroundColor Yellow
Write-Host "     node --run lint" -ForegroundColor Yellow
Write-Host "     node --run test" -ForegroundColor Yellow
Write-Host ""