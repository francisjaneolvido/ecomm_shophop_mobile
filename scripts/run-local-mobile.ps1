[CmdletBinding()]
param(
    [string]$DeviceId,
    [ValidateRange(1, 65535)][int]$Port = 8000,
    [switch]$ConnectOnly
)

$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adbPath = if ($adbCommand) { $adbCommand.Source } else { $null }
if (-not $adbPath) {
    $sdkCandidates = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME,
        (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Android\Sdk'))
    $localProperties = Join-Path $mobileRoot 'android\local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $sdkLine = Get-Content -LiteralPath $localProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($sdkLine) { $sdkCandidates += $sdkLine.Substring(8).Replace('\\', '\') }
    }
    foreach ($sdkPath in $sdkCandidates) {
        if (-not $sdkPath) { continue }
        $candidate = Join-Path $sdkPath 'platform-tools\adb.exe'
        if (Test-Path -LiteralPath $candidate) { $adbPath = $candidate; break }
    }
}
if (-not $adbPath) { throw 'ADB was not found. Install Android SDK Platform-Tools or set ANDROID_SDK_ROOT.' }

$deviceLines = & $adbPath devices
if ($LASTEXITCODE -ne 0) { throw 'ADB could not list connected devices.' }
$devices = @($deviceLines | ForEach-Object {
    if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
} | Where-Object { $_ -notmatch '^emulator-' })
if (-not $DeviceId) {
    if ($devices.Count -ne 1) { throw 'Connect and authorize one physical Android phone, or supply -DeviceId with its ADB serial.' }
    $DeviceId = $devices[0]
}
if ($DeviceId -notin $devices) { throw 'The selected phone is not connected or USB debugging has not been authorized.' }

$apiBase = "http://127.0.0.1:$Port/api/mobile"
$apiReady = $false
try {
    $probe = Invoke-WebRequest "$apiBase/me" -Headers @{ Accept = 'application/json' } -UseBasicParsing -TimeoutSec 5
    $apiReady = $probe.StatusCode -eq 200 -and $probe.Headers['Content-Type'] -match 'application/json'
} catch {
    $apiResponse = $_.Exception.Response
    if ($apiResponse) {
        $apiReady = [int]$apiResponse.StatusCode -eq 401 -and $apiResponse.ContentType -match 'application/json'
    }
}
if (-not $apiReady) {
    throw "ShopHop API is not reachable on PC port $Port. In ecomm_shophop_web, run: php artisan serve --host=127.0.0.1 --port=$Port"
}

& $adbPath -s $DeviceId reverse "tcp:$Port" "tcp:$Port"
if ($LASTEXITCODE -ne 0) { throw 'The USB connection could not forward the Laravel port.' }
Write-Host "USB connection ready: phone $DeviceId -> PC port $Port"
Write-Host 'Keep the USB cable connected and the Laravel server running.'
if ($ConnectOnly) { return }

Push-Location -LiteralPath $mobileRoot
try {
    & flutter run -d $DeviceId "--dart-define=API_BASE_URL=$apiBase"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed. See the Flutter output above.' }
} finally {
    Pop-Location
}
