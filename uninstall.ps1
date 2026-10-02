<#
.SYNOPSIS
    Automated dev environment uninstaller and rollback script.

.DESCRIPTION
    Rolls back changes made by install.ps1:
    - Restores global VS Code settings from settings.json.bak
    - Uninstalls recommended VS Code extensions
    - Removes downloaded project configuration files (.prettierrc, .gitattributes, .gitignore, oxlint.config.mts)
    - Reverts workspace .vscode/settings.json
    - Restores or removes tsconfig.json
    Supports all VS Code variants (Stable, Insiders, VSCodium, Cursor, code-oss) and both
    user-level (default) and system-level installs. Automatically switches to PowerShell Core
    (pwsh) if available.

.PARAMETER BaseUrl
    Base URL for remote configuration files (used to fetch the extension list). Defaults to xcfio/settings main branch.

.PARAMETER Editor
    VS Code variant to target. Choices: 'code' (default), 'code-insiders', 'codium', 'cursor', 'code-oss'.
    The script also auto-detects the first available CLI when the specified editor is not on PATH.

.PARAMETER Scope
    Uninstall scope for VS Code settings: 'User' (default) or 'System' (machine-wide). Must match
    the scope used during installation.

.PARAMETER SkipSettings
    Skip restoring global VS Code settings.

.PARAMETER SkipExtensions
    Skip uninstalling VS Code extensions.

.PARAMETER SkipConfigs
    Skip removing project configuration files.

.PARAMETER RemoveTsConfig
    Remove tsconfig.json (or restore from tsconfig.json.bak if present).

.PARAMETER Force
    Skip confirmation prompts and force rollback operations.

.PARAMETER NoPwsh
    Prevent relaunching under PowerShell Core (pwsh) when running under Windows PowerShell.

.EXAMPLE
    irm https://raw.githubusercontent.com/xcfio/settings/main/uninstall.ps1 | iex

.EXAMPLE
    .\uninstall.ps1 -SkipExtensions

.EXAMPLE
    .\uninstall.ps1 -Editor code-insiders -Scope System -Force

.EXAMPLE
    .\uninstall.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "https://raw.githubusercontent.com/xcfio/settings/main",

    [ValidateSet("code", "code-insiders", "codium", "cursor", "code-oss")]
    [string]$Editor = "code",

    [ValidateSet("User", "System", "Auto")]
    [string]$Scope = "Auto",

    [switch]$SkipSettings,
    [switch]$SkipExtensions,
    [switch]$SkipConfigs,
    [switch]$RemoveTsConfig,
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
        if (-not $scriptPath -and (Test-Path ".\uninstall.ps1")) {
            $scriptPath = (Resolve-Path ".\uninstall.ps1").Path
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
            # Running via piped iex (e.g., irm https://.../uninstall.ps1 | iex)
            $remoteCmd = "Invoke-RestMethod '$BaseUrl/uninstall.ps1' | Invoke-Expression"
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

    $variantMap = [ordered]@{
        "code"          = @{ Cmds = @("code");          Label = "VS Code Stable"   }
        "code-insiders" = @{ Cmds = @("code-insiders"); Label = "VS Code Insiders" }
        "codium"        = @{ Cmds = @("codium");        Label = "VSCodium"         }
        "cursor"        = @{ Cmds = @("cursor");        Label = "Cursor"           }
        "code-oss"      = @{ Cmds = @("code-oss");      Label = "Code OSS"         }
    }

    $entry = $variantMap[$PreferredEditor]
    if ($entry) {
        foreach ($cmd in $entry.Cmds) {
            $found = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($found) { return @{ Cmd = $cmd; Label = $entry.Label } }
        }
    }

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
        # If neither exists yet, fall back to the User path.
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

$editorLabelMap = @{
    "code"          = "VS Code Stable"
    "code-insiders" = "VS Code Insiders"
    "codium"        = "VSCodium"
    "cursor"        = "Cursor"
    "code-oss"      = "Code OSS"
}
$editorLabel = if ($editorLabelMap.ContainsKey($Editor)) { $editorLabelMap[$Editor] } else { $Editor }

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  Dev Environment Uninstaller (xcfio/settings)" -ForegroundColor Yellow
Write-Host "  Shell  : $shellInfo" -ForegroundColor DarkGray
Write-Host "  OS     : $targetOs" -ForegroundColor DarkGray
Write-Host "  Editor : $editorLabel" -ForegroundColor DarkGray
Write-Host "  Scope  : $(if ($Scope -eq 'Auto') { 'Auto (System → User)' } else { $Scope })" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host ""

# Warn early when system scope may be involved without elevation (Windows)
$mightUseSystem = ($Scope -eq "System") -or ($Scope -eq "Auto")
if ($mightUseSystem -and ($IsWindows -or $env:OS -eq "Windows_NT")) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin -and $Scope -eq "System") {
        Write-Host "[!] WARNING: '-Scope System' requires Administrator privileges on Windows." -ForegroundColor Yellow
        Write-Host "    Settings revert may fail. Re-run as Administrator for system-wide uninstall." -ForegroundColor DarkGray
        Write-Host ""
    }
}

# -------------------------------------------------------------------------
# Step 1: Revert Global VS Code Settings
# -------------------------------------------------------------------------
if (-not $SkipSettings) {
    Write-Host "[1/4] Global VS Code Settings" -ForegroundColor Cyan
    $settingsPath = Get-VSCodeSettingsPath -EditorVariant $Editor -InstallScope $Scope
    $backupPath   = "$settingsPath.bak"

    if (Test-Path $backupPath) {
        try {
            Copy-Item -Path $backupPath -Destination $settingsPath -Force
            Remove-Item -Path $backupPath -Force
            Write-Host "  [+] Restored original settings from $backupPath" -ForegroundColor Green
        } catch {
            Write-Host "  [x] Failed to restore settings from backup: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [-] No backup found at '$backupPath'." -ForegroundColor DarkGray
        Write-Host "      Preserved current settings.json to avoid settings loss." -ForegroundColor DarkGray
    }
} else {
    Write-Host "[1/4] Global VS Code Settings: SKIPPED (-SkipSettings)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Step 2: Uninstall VS Code Extensions
# -------------------------------------------------------------------------
if (-not $SkipExtensions) {
    Write-Host "`n[2/4] VS Code Extensions" -ForegroundColor Cyan

    $cliInfo = Resolve-VSCodeCLI -PreferredEditor $Editor

    if (-not $cliInfo) {
        Write-Host "  [!] No VS Code CLI found on PATH. Searched: code, code-insiders, codium, cursor, code-oss." -ForegroundColor Yellow
    } else {
        $codeCmd   = $cliInfo.Cmd
        $codeLabel = $cliInfo.Label

        if ($codeCmd -ne $Editor) {
            Write-Host "  [!] '$Editor' not found; using '$codeCmd' ($codeLabel) instead." -ForegroundColor Yellow
        } else {
            Write-Host "  [i] Using CLI: $codeCmd ($codeLabel)" -ForegroundColor DarkGray
        }

        try {
            $rawJson = $null
            # Check local extensions.json first if available, else fetch from BaseUrl
            if (Test-Path ".\extensions.json") {
                $rawJson = Get-Content ".\extensions.json" -Raw
            } else {
                $rawJson = Get-WebContent -Url "$BaseUrl/extensions.json"
            }

            $cleanJson       = $rawJson -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
            $recommendations = ($cleanJson | ConvertFrom-Json).recommendations

            if ($recommendations -and $recommendations.Count -gt 0) {
                $installedExtensions = @(& $codeCmd --list-extensions 2>$null)
                $installedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($item in $installedExtensions) {
                    if ($item -and $item.Trim()) { [void]$installedSet.Add($item.Trim()) }
                }

                $total           = $recommendations.Count
                $curr            = 0
                $uninstalledCount = 0
                $skippedCount    = 0

                foreach ($ext in $recommendations) {
                    $curr++
                    $extName = $ext.ToString().Trim()
                    if (-not $extName) { continue }

                    if ($installedSet.Contains($extName)) {
                        Write-Host "  [$curr/$total] [-] Uninstalling $extName..." -ForegroundColor Cyan
                        & $codeCmd --uninstall-extension $extName | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  [$curr/$total] [v] Uninstalled: $extName" -ForegroundColor Green
                            $uninstalledCount++
                        } else {
                            Write-Host "  [$curr/$total] [x] Failed to uninstall: $extName" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "  [$curr/$total] [=] Not installed: $extName" -ForegroundColor DarkGray
                        $skippedCount++
                    }
                }
                Write-Host "  [+] Summary: $total extensions ($uninstalledCount uninstalled, $skippedCount not installed)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [x] Failed to process extensions uninstall: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`n[2/4] VS Code Extensions: SKIPPED (-SkipExtensions)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Step 3: Remove Project Configuration Files (Current Directory)
# -------------------------------------------------------------------------
if (-not $SkipConfigs) {
    Write-Host "`n[3/4] Project Configuration Files" -ForegroundColor Cyan

    # Safety check: do not accidentally wipe tracked files in the source repository itself
    $isSettingsRepo = $false
    if (Test-Path "package.json") {
        try {
            $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
            if ($pkg.name -eq "settings" -and $pkg.repository.url -match "xcfio/settings") {
                $isSettingsRepo = $true
            }
        } catch {}
    }

    if ($isSettingsRepo -and -not $Force) {
        Write-Host "  [!] Running inside the 'xcfio/settings' source repository." -ForegroundColor Yellow
        Write-Host "      Skipping removal of repository config files. (Pass -Force to override)" -ForegroundColor DarkGray
    } else {
        $projectFiles = @(
            ".prettierrc",
            ".gitattributes",
            ".gitignore",
            "oxlint.config.mts"
        )

        foreach ($file in $projectFiles) {
            $target = Join-Path (Get-Location) $file
            if (Test-Path $target) {
                try {
                    Remove-Item -Path $target -Force
                    Write-Host "  [-] Removed: $file" -ForegroundColor Green
                } catch {
                    Write-Host "  [x] Failed to remove $file : $_" -ForegroundColor Red
                }
            } else {
                Write-Host "  [=] Not found: $file" -ForegroundColor DarkGray
            }
        }

        # Workspace .vscode/settings.json cleanup
        $vscodeDir      = Join-Path (Get-Location) ".vscode"
        $vscodeSettings = Join-Path $vscodeDir "settings.json"
        $vscodeBackup   = "$vscodeSettings.bak"

        if (Test-Path $vscodeBackup) {
            try {
                Copy-Item -Path $vscodeBackup -Destination $vscodeSettings -Force
                Remove-Item -Path $vscodeBackup -Force
                Write-Host "  [+] Restored .vscode/settings.json from backup" -ForegroundColor Green
            } catch {
                Write-Host "  [x] Failed to restore .vscode/settings.json from backup: $_" -ForegroundColor Red
            }
        } elseif (Test-Path $vscodeSettings) {
            try {
                $content = Get-Content $vscodeSettings -Raw
                $clean   = $content -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
                $obj     = $clean | ConvertFrom-Json
                if ($obj.PSObject.Properties['oxc.configPath']) {
                    $obj.PSObject.Properties.Remove('oxc.configPath')
                    $propCount = @($obj.PSObject.Properties).Count
                    if ($propCount -eq 0) {
                        Remove-Item -Path $vscodeSettings -Force
                        Write-Host "  [-] Removed empty .vscode/settings.json" -ForegroundColor Green
                        # Remove .vscode dir if now empty
                        $remaining = @(Get-ChildItem -Path $vscodeDir -Force 2>$null)
                        if ($remaining.Count -eq 0) {
                            Remove-Item -Path $vscodeDir -Force
                            Write-Host "  [-] Removed empty .vscode directory" -ForegroundColor Green
                        }
                    } else {
                        $updated   = $obj | ConvertTo-Json -Depth 10
                        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
                        [System.IO.File]::WriteAllText($vscodeSettings, $updated + "`n", $utf8NoBom)
                        Write-Host "  [-] Removed oxc.configPath from .vscode/settings.json" -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "  [!] Could not parse .vscode/settings.json to remove oxc.configPath: $_" -ForegroundColor DarkGray
            }
        }
    }
} else {
    Write-Host "`n[3/4] Project Configuration Files: SKIPPED (-SkipConfigs)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Step 4: Optional TypeScript Configuration Rollback
# -------------------------------------------------------------------------
Write-Host "`n[4/4] TypeScript Configuration" -ForegroundColor Cyan
$tsconfigPath   = Join-Path (Get-Location) "tsconfig.json"
$tsconfigBackup = "$tsconfigPath.bak"

if (Test-Path $tsconfigBackup) {
    try {
        Copy-Item -Path $tsconfigBackup -Destination $tsconfigPath -Force
        Remove-Item -Path $tsconfigBackup -Force
        Write-Host "  [+] Restored original tsconfig.json from backup" -ForegroundColor Green
    } catch {
        Write-Host "  [x] Failed to restore tsconfig.json from backup: $_" -ForegroundColor Red
    }
} elseif ($RemoveTsConfig -and (Test-Path $tsconfigPath)) {
    try {
        Remove-Item -Path $tsconfigPath -Force
        Write-Host "  [-] Removed: tsconfig.json" -ForegroundColor Green
    } catch {
        Write-Host "  [x] Failed to remove tsconfig.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  [-] No tsconfig.json backup found; file left intact." -ForegroundColor DarkGray
    Write-Host "      (Pass -RemoveTsConfig to explicitly delete tsconfig.json)" -ForegroundColor DarkGray
}

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Uninstall completed successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
