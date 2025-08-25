# --- Prereqs: Ensure Python and Node are available on fresh machines ---
function Ensure-Python {
    try {
        python --version | Out-Null
    } catch {
        $installer = Join-Path $PSScriptRoot "PythonInstaller.exe"
        if (Test-Path $installer) {
            Write-Host "Python not found. Installing Python..."
            Start-Process -FilePath $installer -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1" -Wait -Verb RunAs
        } else {
            throw "Python not found and PythonInstaller.exe is missing."
        }
    }
}

function Ensure-Nvm {
    if ($env:NVM_HOME -and (Test-Path (Join-Path $env:NVM_HOME "nvm.exe"))) { return }
    $nvmHome = "C:\Program Files\nvm"
    $nvmExe = Join-Path $nvmHome "nvm.exe"
    if (Test-Path $nvmExe) {
        $env:NVM_HOME = $nvmHome
        if (-not $env:NVM_SYMLINK) { $env:NVM_SYMLINK = "C:\Program Files\nodejs" }
        return
    }
    Write-Host "Installing nvm for Windows..."
    $nvmSetupUrl = "https://github.com/coreybutler/nvm-windows/releases/download/1.1.12/nvm-setup.exe"
    $tmp = Join-Path $env:TEMP "nvm-setup.exe"
    Invoke-WebRequest $nvmSetupUrl -OutFile $tmp
    Start-Process -FilePath $tmp -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -Verb RunAs
    $env:NVM_HOME = $nvmHome
    if (-not $env:NVM_SYMLINK) { $env:NVM_SYMLINK = "C:\Program Files\nodejs" }
}

function Ensure-Node {
    $target = "20.11.1"
    $minMajor = 18; $minMinor = 19
    try {
        $v = node -v 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) {
            $m = [regex]::Match($v, "v(\d+)\.(\d+)")
            if ($m.Success) {
                $major = [int]$m.Groups[1].Value
                $minor = [int]$m.Groups[2].Value
                if ($major -gt $minMajor -or ($major -eq $minMajor -and $minor -ge $minMinor)) {
                    return
                }
            }
        }
    } catch { }

    Ensure-Nvm
    if (-not (Test-Path (Join-Path $env:NVM_HOME "nvm.exe"))) { throw "nvm installation failed." }
    & (Join-Path $env:NVM_HOME "nvm.exe") install $target | Out-Host
    & (Join-Path $env:NVM_HOME "nvm.exe") use $target | Out-Host
    if ($env:NVM_SYMLINK) { $env:Path = "$env:NVM_SYMLINK;$env:Path" }
}

Ensure-Python
Ensure-Node

# --- OpenALPR: prefer precompiled binaries if present ---
$precompiledDir = Join-Path $PSScriptRoot "OpenALPR\openalpr-2.3.0-win-64bit\openalpr_64"
if (Test-Path $precompiledDir) {
    $env:Path = "$precompiledDir;$env:Path"
    $precompiledConf = Join-Path $precompiledDir "openalpr.conf"
    if (Test-Path $precompiledConf) {
        [System.Environment]::SetEnvironmentVariable("OPENALPR_CONFIG_FILE", $precompiledConf, "Process")
    }
}

# If alpr is already available, skip building
$alprCmd = Get-Command "alpr" -ErrorAction SilentlyContinue
if ($alprCmd) {
    Write-Host "OpenALPR engine found at $($alprCmd.Path). Skipping build."
} else {
    # --- OpenALPR: idempotent vcpkg-based build for Windows x64 ---
    function Ensure-VcpkgDeps {
        param(
            [string]$VcpkgRoot
        )
        # Install required ports (Release x64 windows). Re-entrant: vcpkg skips installed.
        & "$VcpkgRoot\vcpkg.exe" install `
            opencv[contrib]:x64-windows `
            tesseract:x64-windows `
            leptonica:x64-windows `
            jsoncpp:x64-windows `
            log4cplus:x64-windows | Out-Host

        # Make sure user-wide integration is on (adds a toolchain file).
        & "$VcpkgRoot\vcpkg.exe" integrate install | Out-Null
    }

    function Build-OpenALPR {
        param(
            [string]$SrcZipUrl = "https://github.com/openalpr/openalpr/archive/refs/tags/v2.3.0.zip",
            [string]$WorkRoot = "./OpenALPRSource",
            [string]$Triplet = "x64-windows"
        )

        $ErrorActionPreference = "Stop"
        $srcZip = Join-Path $PWD "openalpr-source.zip"
        $srcDir = Join-Path $WorkRoot "openalpr-2.3.0"
        $buildDir = Join-Path $srcDir "build"
        $installDir = Join-Path $srcDir "install"

        if (-not (Test-Path $WorkRoot)) { New-Item -ItemType Directory -Path $WorkRoot | Out-Null }

        # 1) Fetch source if missing
        if (-not (Test-Path $srcDir)) {
            Write-Host "Downloading OpenALPR source code..."
            Invoke-WebRequest $SrcZipUrl -OutFile $srcZip
            Expand-Archive $srcZip -DestinationPath $WorkRoot -Force
        } else {
            Write-Host "OpenALPR source exists at $srcDir"
        }

        # 2) Ensure vcpkg deps
        $vcpkgRoot = (Resolve-Path "./vcpkg").Path
        if (-not (Test-Path "$vcpkgRoot\vcpkg.exe")) {
            throw "vcpkg not found at $vcpkgRoot (earlier step should have bootstrapped it)."
        }
        Ensure-VcpkgDeps -VcpkgRoot $vcpkgRoot

        # 3) Configure (idempotent): clean or use CMake multi-config build dir pattern
        if (Test-Path $buildDir) {
            Write-Host "Cleaning previous CMake cache..."
            Remove-Item -LiteralPath $buildDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $buildDir | Out-Null
        if (Test-Path $installDir) {
            Remove-Item -LiteralPath $installDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $installDir | Out-Null

        $toolchain = & "$vcpkgRoot\vcpkg.exe" fetch cmake-toolchain
        if (-not $toolchain) { $toolchain = (Join-Path $vcpkgRoot "scripts\buildsystems\vcpkg.cmake") }

        Push-Location $buildDir
        try {
            Write-Host "Configuring OpenALPR with CMake + vcpkg..."
            cmake -S ../src -B . `
                -G "MinGW Makefiles" `
                -DCMAKE_C_COMPILER="C:/ProgramData/chocolatey/lib/mingw/tools/install/mingw64/bin/gcc.exe" `
                -DCMAKE_CXX_COMPILER="C:/ProgramData/chocolatey/lib/mingw/tools/install/mingw64/bin/g++.exe" `
                -DCMAKE_BUILD_TYPE=Release `
                -DBUILD_UTILITIES=ON `
                -DBUILD_BINDINGS=OFF `
                -DWITH_TEST=OFF `
                -DOPENALPR_RUN_PATH="$installDir"

            Write-Host "Building OpenALPR (Release)..."
            cmake --build . --config Release --parallel

            Write-Host "Installing OpenALPR to $installDir..."
            cmake --install . --config Release --prefix "$installDir"
        }
        finally { Pop-Location }

        # 4) Runtime data (needed at runtime): copy runtime_data near binaries
        $runtimeDataSrc = Join-Path $srcDir "runtime_data"
        $runtimeDataDst = Join-Path $installDir "share\openalpr\runtime_data"
        if (-not (Test-Path $runtimeDataDst)) { New-Item -ItemType Directory -Path $runtimeDataDst -Force | Out-Null }
        Copy-Item -Path (Join-Path $runtimeDataSrc "*") -Destination $runtimeDataDst -Recurse -Force

        # 5) Put bin on PATH for this session and recommend permanent set
        $binPath = Join-Path $installDir "bin"
        if (-not (Test-Path $binPath)) {
            $binPath = Get-ChildItem -Path $installDir -Recurse -Filter "alpr.exe" -ErrorAction SilentlyContinue |
                       Select-Object -First 1 | Split-Path
        }
        if (-not $binPath) { throw "alpr.exe not found after install." }
        $env:Path = "$binPath;$env:Path"

        $vcpkgBin = Join-Path $vcpkgRoot "installed\$Triplet\bin"
        if (Test-Path $vcpkgBin) { $env:Path = "$vcpkgBin;$env:Path" }

        $globalConfig = Join-Path $installDir "share\openalpr\openalpr.conf"
        if (Test-Path $globalConfig) {
            [System.Environment]::SetEnvironmentVariable("OPENALPR_CONFIG_FILE", $globalConfig, "Process")
        }

        $alpr = Get-Command "alpr" -ErrorAction SilentlyContinue
        if (-not $alpr) { throw "OpenALPR not on PATH for this session." }

        Write-Host "OpenALPR installed to: $installDir"
        Write-Host "alpr path: $($alpr.Path)"
    }

    try {
        Write-Host "`nChecking for OpenALPR engine..."
        $alprPath = Get-Command "alpr" -ErrorAction SilentlyContinue
        if (-not $alprPath) { Build-OpenALPR } else { Write-Host "OpenALPR engine found at $($alprPath.Path)" }
    } catch {
        Write-Host "ERROR installing OpenALPR engine: $($_.Exception.Message)"; exit 1
    }
}
# --- end OpenALPR block ---

$env:LOCAL_MODE = "true"
$env:DB_HOST = "localhost"
$env:DB_USER = "root"
$env:DB_PASSWORD = "root"
$env:DB_NAME = "license_plates_db"
$env:UPLOAD_DIR = "uploads"

# In LOCAL_MODE, skip Docker/MySQL
if ($env:LOCAL_MODE -eq "true") {
    Write-Host "LOCAL_MODE enabled: skipping Docker/MySQL startup."
} else {
    try {
        Write-Host "`nEnsuring Docker is running..."
        $maxRetries = 12; $retry = 0
        while ($true) {
            try { docker info | Out-Null; break } catch {
                if ($retry -eq 0) {
                    Write-Host "Starting Docker Desktop..."
                    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                }
                if ($retry -ge $maxRetries) { throw "Docker failed to start." }
                Start-Sleep -Seconds 5; $retry++
            }
        }
    } catch { Write-Host "ERROR: $_"; exit 1 }

    try {
        if (-not (docker ps --filter "name=licenseplates-db" --format "{{.Names}}")) {
            docker run --name licenseplates-db -e MYSQL_ROOT_PASSWORD=root `
                       -e MYSQL_DATABASE=license_plates_db -p 3306:3306 -d mysql:8
            Start-Sleep -Seconds 30
        }
    } catch { Write-Host "ERROR starting MySQL: $_"; exit 1 }

    $schema = @"
CREATE TABLE IF NOT EXISTS plates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    plate_number VARCHAR(20),
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    image_path VARCHAR(255)
);
"@
    $schema | docker exec -i licenseplates-db mysql -uroot -proot license_plates_db
}

cd backend
python -m pip install -r requirements.txt
if (-not (Test-Path uploads)) { New-Item -ItemType Directory uploads | Out-Null }
$backendPath = (Get-Location).Path
Start-Job { Set-Location -Path $using:backendPath; python app.py }

cd ../frontend
npm install
$frontendPath = (Get-Location).Path
Start-Job { Set-Location -Path $using:frontendPath; npx ng serve --proxy-config proxy.conf.json --open }

Write-Host "`nBackend and frontend started. Use 'Get-Job' and 'Stop-Job' to manage them."
Write-Host "Frontend: http://localhost:4200"
Write-Host "Backend API: http://localhost:5000"
