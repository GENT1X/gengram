# Builds tdjson.dll (TDLib) for Windows x64.
# Run from "x64 Native Tools Command Prompt for VS 2022":
#   powershell -ExecutionPolicy Bypass -File build_tdlib_windows.ps1

$ErrorActionPreference = "Stop"
if (-not (Get-Command cl -ErrorAction SilentlyContinue)) { throw "cl not found: run this from x64 Native Tools Command Prompt" }
$root = "$PSScriptRoot\tdlib_build"
New-Item -ItemType Directory -Force $root | Out-Null
Set-Location $root

if (-not (Test-Path "td")) { git clone --depth 1 https://github.com/tdlib/td.git }
if (-not (Test-Path "vcpkg")) {
    git clone --depth 1 https://github.com/microsoft/vcpkg.git
    .\vcpkg\bootstrap-vcpkg.bat
}

.\vcpkg\vcpkg.exe install gperf:x64-windows openssl:x64-windows zlib:x64-windows

Set-Location "$root\td"
if (Test-Path build) { Remove-Item -Recurse -Force build }
New-Item -ItemType Directory -Force build | Out-Null
Set-Location build
cmake -G Ninja -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl -DCMAKE_BUILD_TYPE=Release -DVCPKG_TARGET_TRIPLET=x64-windows -DCMAKE_TOOLCHAIN_FILE="$root\vcpkg\scripts\buildsystems\vcpkg.cmake" ..
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
cmake --build . --target tdjson -j 1
if ($LASTEXITCODE -ne 0) { throw "build failed" }

$out = "$PSScriptRoot\tdlib_dll"
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item "tdjson.dll" $out
Copy-Item "$root\vcpkg\installed\x64-windows\bin\*.dll" $out
Write-Host "Done. DLL files are in: $out"
