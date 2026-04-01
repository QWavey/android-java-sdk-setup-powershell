function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Not running as admin. Requesting elevation..."

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    $psi.UseShellExecute = $true

    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Host "Admin permission denied. Exiting..."
    }

    exit
}

$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
$JavaRoot = "$env:LOCALAPPDATA\Java"

$ToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$JavaUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"

$SdkZip = "$env:TEMP\cmdline-tools.zip"
$JavaZip = "$env:TEMP\jdk.zip"

function Ask-Overwrite($path) {
    if (Test-Path $path) {
        $answer = Read-Host "$path already exists. Overwrite? (y/n)"
        if ($answer -ne "y") {
            Write-Host "Skipped: $path"
            return $false
        }
        Remove-Item -Recurse -Force $path
    }
    return $true
}

if (Ask-Overwrite "$JavaRoot\jdk17") {

    Write-Host "Downloading Java..."

    New-Item -ItemType Directory -Force -Path $JavaRoot | Out-Null

    Start-BitsTransfer -Source $JavaUrl -Destination $JavaZip

    if (!(Test-Path $JavaZip)) {
        Write-Host "Java download failed"
        exit 1
    }

    Expand-Archive -Force $JavaZip "$JavaRoot\temp"

    $javaFolder = Get-ChildItem "$JavaRoot\temp" | Select-Object -First 1

    Move-Item "$JavaRoot\temp\$($javaFolder.Name)" "$JavaRoot\jdk17"

    Remove-Item -Recurse -Force "$JavaRoot\temp"
    Remove-Item -Force $JavaZip
}

if (Ask-Overwrite "$SdkRoot\cmdline-tools\latest") {

    Write-Host "Downloading Android SDK tools..."

    New-Item -ItemType Directory -Force -Path "$SdkRoot\cmdline-tools" | Out-Null

    Start-BitsTransfer -Source $ToolsUrl -Destination $SdkZip

    Expand-Archive -Force $SdkZip "$SdkRoot\cmdline-tools\latest-temp"

    if (Test-Path "$SdkRoot\cmdline-tools\latest") {
        Remove-Item -Recurse -Force "$SdkRoot\cmdline-tools\latest"
    }

    New-Item -ItemType Directory -Force -Path "$SdkRoot\cmdline-tools\latest" | Out-Null

    Move-Item "$SdkRoot\cmdline-tools\latest-temp\cmdline-tools\*" "$SdkRoot\cmdline-tools\latest"

    Remove-Item -Recurse -Force "$SdkRoot\cmdline-tools\latest-temp"
    Remove-Item -Force $SdkZip
}

$env:JAVA_HOME = "$JavaRoot\jdk17"
$env:ANDROID_SDK_ROOT = $SdkRoot

$env:Path += ";$JavaRoot\jdk17\bin;$SdkRoot\cmdline-tools\latest\bin;$SdkRoot\platform-tools"

[Environment]::SetEnvironmentVariable("JAVA_HOME", "$JavaRoot\jdk17", "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", "$SdkRoot", "User")

$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($oldPath -notlike "*jdk17*") {
    $newPath = "$oldPath;$JavaRoot\jdk17\bin;$SdkRoot\cmdline-tools\latest\bin;$SdkRoot\platform-tools"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

Write-Host "Installing SDK packages..."

& "$SdkRoot\cmdline-tools\latest\bin\sdkmanager.bat" --licenses

& "$SdkRoot\cmdline-tools\latest\bin\sdkmanager.bat" `
    "platform-tools" `
    "platforms;android-34" `
    "build-tools;34.0.0"

Write-Host "===================================="
Write-Host "ANDROID SDK + JAVA INSTALL COMPLETE"
Write-Host "Restart terminal"
Write-Host "===================================="