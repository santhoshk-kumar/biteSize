<#
.SYNOPSIS
    Automated Portable Android SDK & APK Builder for BiteSize (No Android Studio, No Admin Rights Needed)
.DESCRIPTION
    1. Downloads portable OpenJDK 17 zip (Adoptium Temurin) if Java is missing.
    2. Downloads official Google cmdline-tools and sets up folder structure.
    3. Configures ANDROID_HOME and PATH persistently.
    4. Installs Android 34 platforms & build-tools and accepts licenses automatically.
    5. Runs flutter build apk --release --split-per-abi.
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  BiteSize - Automated Android SDK & APK Builder" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$androidDir = "$env:USERPROFILE\Android"
$sdkRoot = "$androidDir\Sdk"
$jdkDir = "$androidDir\jdk-17"
$cmdlineDir = "$sdkRoot\cmdline-tools"
$latestDir = "$cmdlineDir\latest"

if (-not (Test-Path $androidDir)) {
    New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
}

# -------------------------------------------------------------
# 1. SETUP JAVA 17 (Portable Adoptium OpenJDK 17)
# -------------------------------------------------------------
Write-Host "`n[1/5] Checking Java Development Kit (JDK 17)..." -ForegroundColor Yellow

$javaReady = $false
$javaExe = Get-Command java -ErrorAction SilentlyContinue

if ($javaExe) {
    try {
        $versionOutput = (java -version 2>&1 | Out-String)
        if ($versionOutput -match '17\.' -or $versionOutput -match '21\.') {
            Write-Host "Existing compatible Java found: $($javaExe.Source)" -ForegroundColor Green
            $javaReady = $true
        }
    } catch {}
}

if (-not $javaReady -and (Test-Path "$jdkDir\bin\java.exe")) {
    $env:JAVA_HOME = $jdkDir
    $env:PATH = "$jdkDir\bin;$env:PATH"
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkDir, "User")
    Write-Host "Using portable Java at: $jdkDir" -ForegroundColor Green
    $javaReady = $true
}

if (-not $javaReady) {
    Write-Host "Downloading portable Eclipse Temurin OpenJDK 17 (~160MB)..." -ForegroundColor Cyan
    $jdkZip = "$env:TEMP\temurin-jdk-17.zip"
    $jdkUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
    
    Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZip -UseBasicParsing
    
    Write-Host "Extracting JDK 17 to $jdkDir..." -ForegroundColor Cyan
    $tempJdkExtract = "$env:TEMP\jdk-extract"
    if (Test-Path $tempJdkExtract) { Remove-Item -Recurse -Force $tempJdkExtract }
    Expand-Archive -Path $jdkZip -DestinationPath $tempJdkExtract -Force
    
    $extractedFolder = Get-ChildItem -Path $tempJdkExtract -Directory | Select-Object -First 1
    if (Test-Path $jdkDir) { Remove-Item -Recurse -Force $jdkDir }
    Move-Item -Path $extractedFolder.FullName -Destination $jdkDir -Force
    
    Remove-Item -Force $jdkZip -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tempJdkExtract -ErrorAction SilentlyContinue
    
    $env:JAVA_HOME = $jdkDir
    $env:PATH = "$jdkDir\bin;$env:PATH"
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkDir, "User")
    Write-Host "JDK 17 installed successfully at $jdkDir" -ForegroundColor Green
}

# -------------------------------------------------------------
# 2. SETUP ANDROID COMMAND-LINE TOOLS
# -------------------------------------------------------------
Write-Host "`n[2/5] Checking Android Command-Line Tools..." -ForegroundColor Yellow

if (-not (Test-Path "$latestDir\bin\sdkmanager.bat")) {
    Write-Host "Downloading official Google Android Command-Line Tools (~140MB)..." -ForegroundColor Cyan
    $cmdlineZip = "$env:TEMP\cmdline-tools.zip"
    $cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    
    Invoke-WebRequest -Uri $cmdlineUrl -OutFile $cmdlineZip -UseBasicParsing
    
    Write-Host "Configuring cmdline-tools in $latestDir..." -ForegroundColor Cyan
    $tempCmdExtract = "$env:TEMP\cmdline-extract"
    if (Test-Path $tempCmdExtract) { Remove-Item -Recurse -Force $tempCmdExtract }
    Expand-Archive -Path $cmdlineZip -DestinationPath $tempCmdExtract -Force
    
    if (-not (Test-Path $cmdlineDir)) {
        New-Item -ItemType Directory -Force -Path $cmdlineDir | Out-Null
    }
    if (Test-Path $latestDir) { Remove-Item -Recurse -Force $latestDir }
    Move-Item -Path "$tempCmdExtract\cmdline-tools" -Destination $latestDir -Force
    
    Remove-Item -Force $cmdlineZip -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tempCmdExtract -ErrorAction SilentlyContinue
    Write-Host "Cmdline-tools installed successfully at $latestDir" -ForegroundColor Green
} else {
    Write-Host "Cmdline-tools already present at $latestDir" -ForegroundColor Green
}

# -------------------------------------------------------------
# 3. SET ENVIRONMENT VARIABLES (ANDROID_HOME & PATH)
# -------------------------------------------------------------
Write-Host "`n[3/5] Registering Environment Variables..." -ForegroundColor Yellow
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:PATH = "$latestDir\bin;$sdkRoot\platform-tools;$env:PATH"

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentUserPath -notlike "*$latestDir\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$latestDir\bin;$sdkRoot\platform-tools;$jdkDir\bin", "User")
}
Write-Host "ANDROID_HOME configured as: $sdkRoot" -ForegroundColor Green

# -------------------------------------------------------------
# 4. INSTALL PLATFORMS, BUILD-TOOLS & ACCEPT LICENSES
# -------------------------------------------------------------
Write-Host "`n[4/5] Installing Android 34 platforms, build-tools, and accepting licenses..." -ForegroundColor Yellow
$sdkmanager = "$latestDir\bin\sdkmanager.bat"

# Install packages
& cmd.exe /c "echo y | `"$sdkmanager`" --install `"platform-tools`" `"platforms;android-34`" `"build-tools;34.0.0`""

# Accept licenses
& cmd.exe /c "echo y | `"$sdkmanager`" --licenses"

# Link to Flutter
Write-Host "Configuring Flutter Android SDK path..." -ForegroundColor Cyan
& flutter config --android-sdk "$sdkRoot"
& cmd.exe /c "echo y | flutter doctor --android-licenses"

# -------------------------------------------------------------
# 5. BUILD RELEASE APK
# -------------------------------------------------------------
Write-Host "`n[5/5] Compiling BiteSize Release APKs..." -ForegroundColor Yellow
$projectDir = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location -Path $projectDir

& flutter pub get
& flutter build apk --release --split-per-abi

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE! Your release APKs are ready:" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

Get-ChildItem -Path "$projectDir\build\app\outputs\flutter-apk\*.apk" | ForEach-Object {
    Write-Host " -> $($_.FullName) ($([math]::Round($_.Length / 1MB, 2)) MB)" -ForegroundColor Cyan
}
