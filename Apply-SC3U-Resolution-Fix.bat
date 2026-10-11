@echo off
setlocal DisableDelayedExpansion
set "SC3U_PATCH_SELF=%~f0"
set "SC3U_PATCH_TARGET=%~1"
set "SC3U_PATCH_UNDO=0"
if /i "%~1"=="/undo" (
    set "SC3U_PATCH_UNDO=1"
    set "SC3U_PATCH_TARGET=%~2"
)
powershell.exe -NoLogo -NoProfile -Command "& ([scriptblock]::Create(([IO.File]::ReadAllText($env:SC3U_PATCH_SELF) -split '(?m)^# POWERSHELL\r?$', 2)[1]))"
set "SC3U_PATCH_EXIT=%ERRORLEVEL%"
echo.
if not defined SC3U_PATCH_NO_PAUSE pause
exit /b %SC3U_PATCH_EXIT%

# POWERSHELL
$ErrorActionPreference = 'Stop'
$encoding = [Text.Encoding]::GetEncoding(28591)
$bom = $encoding.GetString([byte[]](239, 187, 191))
$keys = '(?im)^[ \t]*(?:SupportedResolutions|ForceD3D9On12|FullscreenMode)[ \t]*=[^\r\n]*(?:\r?\n|$)'
$configNames = @('DDrawCompat-SC3U.ini', 'DDrawCompatOverlay-SC3U.ini')

function Read-Config($Path) {
    if (-not [IO.File]::Exists($Path)) { return '' }
    $text = $encoding.GetString([IO.File]::ReadAllBytes($Path))
    if ($text.Contains([string][char]0)) { throw "Unsupported UTF-16 configuration: $Path" }
    if ($text.StartsWith($bom)) { $text = $text.Substring(3) }
    return $text
}

function With-Settings($Text, $Settings) {
    $text = [regex]::Replace($Text, $keys, '')
    if ($text.Length -and -not $text.EndsWith("`n")) { $text += "`r`n" }
    return $text + $Settings
}

try {
    Write-Host 'SimCity 3000 Unlimited - Native Resolution and Menu Fix'
    $folder = $env:SC3U_PATCH_TARGET
    if (-not $folder) { $folder = [IO.Path]::GetDirectoryName($env:SC3U_PATCH_SELF) }
    $apps = $null
    foreach ($candidate in @($folder, (Join-Path $folder 'Apps'))) {
        if ([IO.File]::Exists((Join-Path $candidate 'SC3U.exe'))) {
            $apps = [IO.Path]::GetFullPath($candidate)
            break
        }
    }
    if (-not $apps) {
        throw 'SC3U.exe was not found. Put this BAT in the game folder or Apps folder, or pass the game folder as its argument.'
    }
    if (Get-Process -Name SC3U -ErrorAction SilentlyContinue) {
        throw 'Close SimCity 3000 Unlimited before applying or undoing this fix.'
    }

    $backup = Join-Path $apps 'SC3U-Resolution-Fix-Backup'
    $marker = Join-Path $backup 'patch-id.txt'
    $patchId = 'SC3U Native Resolution Fix 1'
    if ([IO.Directory]::Exists($backup) -and
        (-not [IO.File]::Exists($marker) -or [IO.File]::ReadAllText($marker) -ne $patchId)) {
        throw "The backup folder belongs to another installation. Keep it safe and rename it first: $backup"
    }

    if ($env:SC3U_PATCH_UNDO -eq '1') {
        if (-not [IO.File]::Exists($marker)) { throw 'No backup from this installer was found.' }
        foreach ($name in $configNames) {
            $original = Join-Path $backup ($name + '.original')
            if (-not [IO.File]::Exists($original)) { continue }
            $path = Join-Path $apps $name
            $settings = ([regex]::Matches((Read-Config $original), $keys) | ForEach-Object { $_.Value }) -join ''
            $restored = With-Settings (Read-Config $path) $settings
            if ([IO.File]::Exists($original + '.created') -and -not $restored.Trim()) {
                if ([IO.File]::Exists($path)) { Remove-Item -LiteralPath $path }
            } else {
                [IO.File]::WriteAllBytes($path, $encoding.GetBytes($restored))
            }
        }
        Write-Host 'Undo complete. Original resolution/rendering settings restored; other settings retained.'
        Write-Host "Backups retained: $backup"
        exit 0
    }

    if ([Environment]::OSVersion.Version.Major -lt 10) { throw 'This fix requires Windows 10 or newer.' }
    $dll = Join-Path $apps 'ddraw.dll'
    if (-not [IO.File]::Exists($dll)) {
        throw 'Install DDrawCompat v0.5.3 or newer in Apps first: https://github.com/narzoul/DDrawCompat/releases'
    }
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($dll)
    if ($version.ProductName -ne 'DDrawCompat') {
        throw 'The existing ddraw.dll is not DDrawCompat. This installer cannot configure a different wrapper.'
    }
    if ($version.FileVersion -notmatch '(\d+\.\d+\.\d+)' -or [version]$Matches[1] -lt [version]'0.5.3') {
        throw 'Update DDrawCompat to v0.5.3 or newer before applying this fix.'
    }

    $modes = @('native', '640x480', '800x600', '1024x768', '1280x720', '1360x768', '1920x1080', '1920x1200')
    foreach ($name in @('DDrawCompat.ini') + $configNames) {
        $text = Read-Config (Join-Path $apps $name)
        $values = [regex]::Matches($text, '(?im)^[ \t]*SupportedResolutions[ \t]*=[ \t]*([^#;\r\n]*)')
        foreach ($value in $values) {
            foreach ($mode in $value.Groups[1].Value.Split(',')) {
                $mode = $mode.Trim().ToLowerInvariant()
                if ($mode -match '^(native|[1-9][0-9]*x[1-9][0-9]*)$' -and $modes -notcontains $mode) { $modes += $mode }
            }
        }
    }
    $settings = "SupportedResolutions = $($modes -join ', ')`r`nForceD3D9On12 = on`r`nFullscreenMode = borderless`r`n"
    $plans = @()
    foreach ($name in $configNames) {
        $path = Join-Path $apps $name
        if ($name -eq 'DDrawCompatOverlay-SC3U.ini' -and -not [IO.File]::Exists($path)) { continue }
        $text = Read-Config $path
        $updated = With-Settings $text $settings
        if ($updated -ne $text) { $plans += @{ Name = $name; Path = $path; Text = $updated } }
    }
    if ($plans.Count -eq 0) {
        Write-Host 'The fix is already applied. No files changed.'
        exit 0
    }

    [IO.Directory]::CreateDirectory($backup) | Out-Null
    if (-not [IO.File]::Exists($marker)) { [IO.File]::WriteAllText($marker, $patchId) }
    # Keep the first backup so running the installer again cannot erase the originals.
    foreach ($plan in $plans) {
        $original = Join-Path $backup ($plan.Name + '.original')
        if (-not [IO.File]::Exists($original)) {
            if ([IO.File]::Exists($plan.Path)) {
                [IO.File]::Copy($plan.Path, $original, $false)
            } else {
                [IO.File]::WriteAllBytes($original, [byte[]]@())
                [IO.File]::WriteAllText($original + '.created', '')
            }
        }
    }
    foreach ($plan in $plans) {
        [IO.File]::WriteAllBytes($plan.Path, $encoding.GetBytes($plan.Text))
        Write-Host "Updated: $($plan.Path)"
    }
    Write-Host 'Fix applied. Start the game and choose your monitor resolution in Preferences > Screen Resolution.'
    Write-Host 'Higher resolutions require an existing widescreen-unlocked SC3U.exe. No executable or city saves were edited.'
    Write-Host "Backups: $backup"
    Write-Host 'Undo by running this BAT with /undo, followed by the game folder if needed.'
    exit 0
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'If Windows denies write access, run this BAT as administrator.'
    if ($backup -and [IO.Directory]::Exists($backup)) { Write-Host "Original configuration backups: $backup" }
    exit 1
}
