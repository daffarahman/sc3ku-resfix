$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot 'Apply-SC3U-Resolution-Fix.bat'
$wrapper = Join-Path ([IO.Directory]::GetParent($PSScriptRoot).FullName) 'Apps\ddraw.dll'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('SC3U-Patch-Test-' + [guid]::NewGuid().ToString('N'))
$oldNoPause = $env:SC3U_PATCH_NO_PAUSE
$env:SC3U_PATCH_NO_PAUSE = '1'

function Assert($Condition, $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

function New-Game($Name, $WithWrapper = $true) {
    $root = Join-Path $testRoot $Name
    $apps = Join-Path $root 'Apps'
    [IO.Directory]::CreateDirectory($apps) | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $apps 'SC3U.exe'), [byte[]](77, 90, 1, 2, 3))
    [IO.File]::WriteAllBytes((Join-Path $apps 'SC3.cfg'), [byte[]](1, 2, 3, 4))
    if ($WithWrapper) { [IO.File]::Copy($wrapper, (Join-Path $apps 'ddraw.dll')) }
    return $root
}

function Run-Installer($Root, $Undo = $false, $Script = $installer) {
    $argument = '"' + $Root + '"'
    if ($Undo) { $argument = '/undo ' + $argument }
    $command = '""' + $Script + '" ' + $argument + '"'
    $stdout = Join-Path $testRoot 'stdout.txt'
    $stderr = Join-Path $testRoot 'stderr.txt'
    $run = Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /s /c ' + $command) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Get-Content -LiteralPath $stdout, $stderr | Out-Host
    return $run.ExitCode
}

try {
    $game = New-Game "Game's test & [native] !"
    $apps = Join-Path $game 'Apps'
    $directory = Join-Path $apps 'DDrawCompat.ini'
    $process = Join-Path $apps 'DDrawCompat-SC3U.ini'
    $overlay = Join-Path $apps 'DDrawCompatOverlay-SC3U.ini'
    $directoryText = "FpsLimiter = msgloop(45)`r`nSupportedREsolutions = 640x480, 2560x1600`r`n"
    $processText = "# Keep this comment`r`nFpsLimiter = msgloop(45)`r`nForceD3D9On12 = off`r`nforced3d9on12=off`r`nFullscreenMode=exclusive`r`nSupportedResolutions=1920x1080"
    $overlayText = "LogLevel = none`r`nForceD3D9On12 = off`r`nFullscreenMode = exclusive`r`n"
    [IO.File]::WriteAllText($directory, $directoryText)
    [IO.File]::WriteAllText($process, $processText)
    [IO.File]::WriteAllText($overlay, $overlayText)
    Assert ((Run-Installer $game) -eq 0) 'apply from a different working directory with punctuation in the path'
    foreach ($path in @($process, $overlay)) {
        $text = [IO.File]::ReadAllText($path)
        Assert ($text.Contains('native, 640x480') -and $text.Contains('1920x1200') -and $text.Contains('2560x1600')) 'native/common/custom modes retained'
        Assert ([regex]::Matches($text, '(?im)^ForceD3D9On12\s*=').Count -eq 1) 'duplicate keys removed'
        Assert ($text.Contains('ForceD3D9On12 = on') -and $text.Contains('FullscreenMode = borderless')) 'rendering settings applied at both precedence levels'
    }
    Assert ([IO.File]::ReadAllText($directory) -ceq $directoryText) 'directory configuration unchanged'
    Assert (([IO.File]::ReadAllBytes((Join-Path $apps 'SC3U.exe')) -join ',') -eq '77,90,1,2,3') 'executable unchanged'
    Assert (([IO.File]::ReadAllBytes((Join-Path $apps 'SC3.cfg')) -join ',') -eq '1,2,3,4') 'game preferences unchanged'
    $first = (Get-FileHash -LiteralPath $process).Hash
    Assert ((Run-Installer $game) -eq 0) 'reapply succeeds'
    Assert ((Get-FileHash -LiteralPath $process).Hash -eq $first) 'reapply does not duplicate or change settings'
    $backup = Join-Path $apps 'SC3U-Resolution-Fix-Backup'
    Assert ([IO.File]::ReadAllText((Join-Path $backup 'DDrawCompat-SC3U.ini.original')) -ceq $processText) 'first original backup preserved'
    [IO.File]::WriteAllText($process, [IO.File]::ReadAllText($process).Replace('msgloop(45)', 'msgloop(37)'))
    Assert ((Run-Installer $game $true) -eq 0) 'undo succeeds'
    $undone = [IO.File]::ReadAllText($process)
    Assert ($undone.Contains('msgloop(37)') -and $undone.Contains('# Keep this comment')) 'undo retains later unrelated changes'
    Assert ($undone.Contains('FullscreenMode=exclusive') -and $undone.Contains('SupportedResolutions=1920x1080')) 'undo restores original settings'
    Assert ([regex]::Matches($undone, '(?im)^ForceD3D9On12\s*=\s*off').Count -eq 2) 'undo restores original duplicate-key order'
    Assert ([IO.File]::ReadAllText($overlay) -ceq $overlayText) 'overlay restored'

    $fresh = New-Game 'Fresh installation'
    $freshApps = Join-Path $fresh 'Apps'
    $localInstaller = Join-Path $freshApps 'Apply-SC3U-Resolution-Fix.bat'
    [IO.File]::Copy($installer, $localInstaller)
    Assert ((Run-Installer '' $false $localInstaller) -eq 0) 'double-click placement next to SC3U.exe'
    Assert ((Run-Installer $fresh $true) -eq 0) 'undo newly created config'
    Assert (-not [IO.File]::Exists((Join-Path $freshApps 'DDrawCompat-SC3U.ini'))) 'undo removes only an empty installer-created file'
    Assert (-not [IO.File]::Exists((Join-Path $freshApps 'DDrawCompatOverlay-SC3U.ini'))) 'missing overlay is not created'

    $missing = New-Game 'Missing wrapper' $false
    Assert ((Run-Installer $missing) -eq 1) 'missing wrapper is rejected'
    Assert (-not [IO.Directory]::Exists((Join-Path $missing 'Apps\SC3U-Resolution-Fix-Backup'))) 'rejected prerequisite makes no changes'
    [IO.File]::WriteAllBytes((Join-Path $missing 'Apps\ddraw.dll'), [byte[]](77, 90))
    Assert ((Run-Installer $missing) -eq 1) 'different wrapper is rejected'

    $unicode = New-Game 'UTF-16 config'
    [IO.File]::WriteAllText((Join-Path $unicode 'Apps\DDrawCompat.ini'), 'ForceD3D9On12 = off', [Text.Encoding]::Unicode)
    Assert ((Run-Installer $unicode) -eq 1) 'unsupported encoding is rejected before edits'
    Assert (-not [IO.File]::Exists((Join-Path $unicode 'Apps\DDrawCompat-SC3U.ini'))) 'encoding rejection makes no config changes'
    Write-Host 'PASS: installation, repeat installation, undo, configuration precedence, custom modes, path quoting, preservation, and prerequisite failures.'
} finally {
    $env:SC3U_PATCH_NO_PAUSE = $oldNoPause
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved) -match '^SC3U-Patch-Test-[a-f0-9]{32}$' -and
        [IO.Directory]::Exists($resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
