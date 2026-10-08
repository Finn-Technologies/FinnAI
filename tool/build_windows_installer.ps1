# Builds the FinnAI Windows Release executable and compiles the Inno Setup
# installer (.exe), bundling the Flutter engine, assets, and native runtimes.
#
# Prerequisites: Flutter, Visual Studio C++ workload, Inno Setup 6.

[CmdletBinding()]
param(
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
Set-Location $Root

# 1. Locate Inno Setup Compiler (ISCC.exe)
$Iscc = Get-Command "iscc" -ErrorAction SilentlyContinue
if (-not $Iscc) {
    $KnownPaths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($p in $KnownPaths) {
        if (Test-Path $p) {
            $Iscc = $p
            break
        }
    }
} else {
    $Iscc = $Iscc.Source
}

if (-not $Iscc) {
    Write-Error "Inno Setup compiler (ISCC.exe) was not found in PATH or standard installation directories. Please install Inno Setup 6."
}

# 2. Build Flutter release if requested or if missing
$ReleaseExe = Join-Path $Root "build\windows\x64\runner\Release\finn_ai.exe"
if (-not $SkipFlutterBuild -or -not (Test-Path $ReleaseExe)) {
    Write-Host "Building Flutter Windows Release..."
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Flutter Windows build failed." }
}

if (-not (Test-Path $ReleaseExe)) {
    throw "Release executable not found at: $ReleaseExe"
}

# 3. Compile Inno Setup Script
$IssPath = Join-Path $Root "windows\installer.iss"
if (-not (Test-Path $IssPath)) {
    throw "Installer script not found at: $IssPath"
}

Write-Host "Compiling Windows installer with Inno Setup..."
& $Iscc $IssPath
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed." }

$InstallerDir = Join-Path $Root "build\windows\installer"
$Installer = Get-ChildItem -Path $InstallerDir -Filter "*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($Installer) {
    $SizeMB = [math]::Round($Installer.Length / 1MB, 2)
    Write-Host "`nSuccessfully created Windows installer:" -ForegroundColor Green
    Write-Host "  Path: $($Installer.FullName)"
    Write-Host "  Size: $SizeMB MB`n"
}
