# Rebuilds the llama.cpp runtime FinnAI loads on native Windows (x64),
# from the exact source pinned by the vendored llama_cpp_dart package (the same
# commits the Android and Linux builds use), and installs it where
# windows/CMakeLists.txt bundles it from: windows/native/x64/
#
# What it produces:
#   llama.dll, ggml.dll, ggml-base.dll, mtmd.dll
#   ggml-cpu-*.dll   (one CPU backend per instruction set: AVX, AVX2, AVX-512)
#
# Prerequisites: git, cmake, Visual Studio (MSVC C++ Build Tools).

[CmdletBinding()]
param(
    [string]$Source = "",
    [string]$Output = "",
    [switch]$Vulkan,
    [switch]$KeepBuild,
    [int]$Jobs = 0
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir

$PackageCommit = "1a8c7563cb5382e23bcd20dc5720fc8d8099ec58"
$LlamaCommit = "d6d0ce8215a1c324e8de04b52f9dd65c5edc129f"
$Tag = "v0.9.0-dev.9"
$Repository = "https://github.com/netdur/llama_cpp_dart.git"

if ([string]::IsNullOrEmpty($Output)) {
    $Output = Join-Path $Root "windows\native\x64"
}

if ($Jobs -le 0) {
    $Jobs = [System.Environment]::ProcessorCount
}

if (-not (Get-Command "cmake" -ErrorAction SilentlyContinue)) {
    $KnownPaths = @(
        "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    )
    foreach ($p in $KnownPaths) {
        if (Test-Path (Join-Path $p "cmake.exe")) {
            $env:PATH = "$p;$env:PATH"
            break
        }
    }
    if (-not (Get-Command "cmake" -ErrorAction SilentlyContinue)) {
        $found = Get-ChildItem -Path "C:\Program Files\Microsoft Visual Studio" -Recurse -Filter "cmake.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $env:PATH = "$($found.DirectoryName);$env:PATH"
        }
    }
}

Write-Host "Checking prerequisites (git, cmake)..."
foreach ($tool in @("git", "cmake")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "$tool is required but was not found in PATH."
    }
}

$TempDir = ""
try {
    if ([string]::IsNullOrEmpty($Source)) {
        $TempDir = Join-Path $env:TEMP ("finn-llama-win-" + [System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        $Source = Join-Path $TempDir "llama_cpp_dart"
        Write-Host "Cloning llama_cpp_dart $Tag..."
        git clone --branch $Tag --recurse-submodules --depth 1 --shallow-submodules $Repository $Source
    }

    $CurrentPkgCommit = (git -C $Source rev-parse HEAD).Trim()
    if ($CurrentPkgCommit -ne $PackageCommit) {
        Write-Error "Source checkout does not match llama_cpp_dart $Tag ($PackageCommit). Got: $CurrentPkgCommit"
    }

    $LlamaSubmodule = Join-Path $Source "src\llama.cpp"
    $CurrentLlamaCommit = (git -C $LlamaSubmodule rev-parse HEAD).Trim()
    if ($CurrentLlamaCommit -ne $LlamaCommit) {
        Write-Error "llama.cpp submodule does not match pinned commit $LlamaCommit. Got: $CurrentLlamaCommit"
    }

    $Build = Join-Path $Source "build\win-x64"
    $Install = Join-Path $Build "install"

    Write-Host "Configuring CMake for Windows x64 Release..."
    $CmakeArgs = @(
        "-S", $LlamaSubmodule,
        "-B", $Build,
        "-A", "x64",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_PREFIX=$Install",
        "-DBUILD_SHARED_LIBS=ON",
        "-DGGML_BACKEND_DL=ON",
        "-DGGML_CPU_ALL_VARIANTS=ON",
        "-DGGML_NATIVE=OFF",
        "-DGGML_OPENMP=OFF",
        "-DGGML_BLAS=OFF",
        "-DLLAMA_BUILD_TESTS=OFF",
        "-DLLAMA_BUILD_EXAMPLES=OFF",
        "-DLLAMA_CURL=OFF",
        "-DLLAMA_BUILD_SERVER=OFF",
        "-DLLAMA_BUILD_APP=OFF",
        "-DLLAMA_BUILD_TOOLS=ON",
        "-DMTMD_VIDEO=OFF"
    )

    if ($Vulkan) {
        $CmakeArgs += "-DGGML_VULKAN=ON"
    }

    cmake @CmakeArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed." }

    Write-Host "Building llama.cpp on $Jobs parallel jobs..."
    cmake --build $Build --config Release --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed." }

    Write-Host "Installing binaries to $Install..."
    cmake --install $Build --config Release
    if ($LASTEXITCODE -ne 0) { throw "CMake install failed." }

    # Gather produced DLLs
    $Stage = Join-Path $Build "stage"
    if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null

    $SearchDirs = @(
        (Join-Path $Install "bin"),
        (Join-Path $Install "lib"),
        (Join-Path $Build "bin\Release")
    )

    foreach ($dir in $SearchDirs) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Filter "*.dll" | ForEach-Object {
                if ($_.Name -notlike "llama-*-impl.dll") {
                    Copy-Item -Path $_.FullName -Destination $Stage -Force
                }
            }
        }
    }

    $RequiredDlls = @("llama.dll", "ggml-base.dll")
    foreach ($req in $RequiredDlls) {
        if (-not (Test-Path (Join-Path $Stage $req))) {
            throw "Build finished but required DLL '$req' is missing from stage."
        }
    }

    if (-not (Test-Path $Output)) {
        New-Item -ItemType Directory -Path $Output -Force | Out-Null
    }

    Write-Host "Copying DLLs to $Output..."
    Get-ChildItem -Path $Stage -Filter "*.dll" | Copy-Item -Destination $Output -Force

    Write-Host "Successfully installed Windows llama.cpp binaries into $($Output):"
    Get-ChildItem -Path $Output -Filter "*.dll" | Select-Object Name, Length
}
finally {
    if ($TempDir -and (Test-Path $TempDir) -and (-not $KeepBuild)) {
        Write-Host "Cleaning temporary build directory..."
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}
