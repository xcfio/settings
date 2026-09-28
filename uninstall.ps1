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
    Automatically switches to PowerShell Core (pwsh) if available.

.PARAMETER BaseUrl
    Base URL for remote configuration files (used to fetch the extension list). Defaults to xcfio/settings main branch.

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
    .\uninstall.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "https://raw.githubusercontent.com/xcfio/settings/main",
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

function Get-VSCodeSettingsPath {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return (Join-Path $env:APPDATA "Code\User\settings.json")
    } elseif ($IsMacOS -or ($env:OSTYPE -match "darwin")) {
        return (Join-Path $HOME "Library/Application Support/Code/User/settings.json")
    } else {
        $configDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { (Join-Path $HOME ".config") }
        return (Join-Path $configDir "Code/User/settings.json")
    }
}

# -------------------------------------------------------------------------
# Banner
# -------------------------------------------------------------------------
$shellInfo = "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
$targetOs = if ($IsWindows -or $env:OS -eq "Windows_NT") { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" }

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  Dev Environment Uninstaller (xcfio/settings)" -ForegroundColor Yellow
Write-Host "  Shell : $shellInfo" -ForegroundColor DarkGray
Write-Host "  OS    : $targetOs" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host ""

# -------------------------------------------------------------------------
# Step 1: Revert Global VS Code Settings
# -------------------------------------------------------------------------
if (-not $SkipSettings) {
    Write-Host "[1/4] Global VS Code Settings" -ForegroundColor Cyan
    $settingsPath = Get-VSCodeSettingsPath
    $backupPath = "$settingsPath.bak"

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
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue

    if (-not $codeCmd) {
        Write-Host "  [!] VS Code CLI ('code') not found on PATH. Skipping extensions." -ForegroundColor Yellow
    } else {
        try {
            $rawJson = $null
            # Check local extensions.json first if available, else fetch from BaseUrl
            if (Test-Path ".\extensions.json") {
                $rawJson = Get-Content ".\extensions.json" -Raw
            } else {
                $rawJson = Get-WebContent -Url "$BaseUrl/extensions.json"
            }

            $cleanJson = $rawJson -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
            $recommendations = ($cleanJson | ConvertFrom-Json).recommendations

            if ($recommendations -and $recommendations.Count -gt 0) {
                $installedExtensions = @(& code --list-extensions 2>$null)
                $installedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($item in $installedExtensions) {
                    if ($item -and $item.Trim()) { [void]$installedSet.Add($item.Trim()) }
                }

                $total = $recommendations.Count
                $curr = 0
                $uninstalledCount = 0
                $skippedCount = 0

                foreach ($ext in $recommendations) {
                    $curr++
                    $extName = $ext.ToString().Trim()
                    if (-not $extName) { continue }

                    if ($installedSet.Contains($extName)) {
                        Write-Host "  [$curr/$total] [-] Uninstalling $extName..." -ForegroundColor Cyan
                        & code --uninstall-extension $extName | Out-Null
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
        $vscodeDir = Join-Path (Get-Location) ".vscode"
        $vscodeSettings = Join-Path $vscodeDir "settings.json"
        $vscodeBackup = "$vscodeSettings.bak"

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
                $clean = $content -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
                $obj = $clean | ConvertFrom-Json
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
                        $updated = $obj | ConvertTo-Json -Depth 10
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
$tsconfigPath = Join-Path (Get-Location) "tsconfig.json"
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
