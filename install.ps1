# Tolis VPN 1.1.0 installer
# Install with:  irm https://raw.githubusercontent.com/TurboWarpFan/tolis-vpn/main/install.ps1 | iex
# Set TOLIS_INSTALL_DIR first for a portable install that leaves PATH alone.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch {}

    $base = 'https://raw.githubusercontent.com/TurboWarpFan/tolis-vpn/main'
    $sha = '498c1820181d5619ffaea127cfd51d290d59081972f4f47c672db41e2af83f7e'
    $dir = if ($env:TOLIS_INSTALL_DIR) { $env:TOLIS_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\Tolis' }
    $exe = Join-Path $dir 'tolis.exe'
    $old = Join-Path $dir 'tolis.old.exe'

    Write-Host ''
    Write-Host '  Tolis VPN 1.1.0' -ForegroundColor Cyan
    Write-Host '  Installing...'

    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (Test-Path $exe) {
        # Disconnect a running copy so the user's internet settings are restored first.
        try { & $exe offline --quiet | Out-Null } catch {}
        Remove-Item $old -Force -ErrorAction SilentlyContinue
        Rename-Item $exe 'tolis.old.exe' -Force -ErrorAction SilentlyContinue
    }

    $tmp = Join-Path $dir 'tolis.download'
    Invoke-WebRequest -UseBasicParsing -Uri "$base/tolis.exe" -OutFile $tmp
    $got = (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash.ToLower()
    if ($got -ne $sha) {
        Remove-Item $tmp -Force
        throw 'The download was corrupted (checksum mismatch). Please run the install command again.'
    }
    Move-Item -Force $tmp $exe
    Invoke-WebRequest -UseBasicParsing -Uri "$base/tolis.json" -OutFile (Join-Path $dir 'server.json')
    Remove-Item $old -Force -ErrorAction SilentlyContinue

    if (-not $env:TOLIS_INSTALL_DIR) {
        # Edit the raw registry value so %VARIABLES% in the user's PATH survive.
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
        $path = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        $parts = @($path -split ';' | Where-Object { $_ })
        if ($parts -notcontains $dir) {
            $key.SetValue('Path', (($parts + $dir) -join ';'), 'ExpandString')
        }
        $key.Close()
        # Setting a variable this way also tells Windows the environment changed.
        [Environment]::SetEnvironmentVariable('TOLIS_HOME', $dir, 'User')
    }
    if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$env:Path;$dir" }

    Write-Host '  Installed!' -ForegroundColor Green
    Write-Host ''
    Write-Host '  To connect, type:  ' -NoNewline
    Write-Host 'tolis online' -ForegroundColor Yellow
    Write-Host '  (From Command Prompt, open a new window first.)' -ForegroundColor DarkGray
    Write-Host ''
}
