#Requires -Modules Logging
#Requires -Modules Hooks

if ($Env:INSTALL_SOURCEMOD -notin @("true", "1", "yes")) {
    Write-Log "INSTALL_SOURCEMOD is not enabled. Skipping SourceMod installation."
    return
}

Invoke-Hook "PreInstallSourceMod"

Write-Log "Installing SourceMod..."

$metaModUrl = $Env:METAMOD_URL
$sourceModUrl = $Env:SOURCEMOD_URL

if (-not $metaModUrl) {
    $metaModUrl = "https://mms.alliedmods.net/mmsdrop/${Env:METAMOD_MAJOR_VERSION}/mmsource-${Env:METAMOD_VERSION}-linux.tar.gz"
}

if (-not $sourceModUrl) {
    $sourceModUrl = "https://sm.alliedmods.net/smdrop/${Env:SOURCEMOD_MAJOR_VERSION}/sourcemod-${Env:SOURCEMOD_VERSION}-linux.tar.gz"
}

$gameDir = "${Env:OVERLAY_DIR}/${Env:GAME_MOD}"

if (-not (Test-Path -Path $gameDir)) {
    Write-Log "Game directory $gameDir does not exist. Creating it."
    New-Item -ItemType Directory -Path $gameDir | Out-Null
}

if (-not (Test-Path -Path "$gameDir/addons/metamod.vdf")) {
    Write-Log "Downloading MetaMod from $metaModUrl"
    curl -fsSL --retry 3 --output /tmp/mmsource.tar.gz "$metaModUrl"
    if ($LASTEXITCODE -ne 0) { throw "Failed to download MetaMod from $metaModUrl" }

    Write-Log "Extracting MetaMod to $gameDir"
    tar -xzf /tmp/mmsource.tar.gz -C $gameDir
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract MetaMod" }
} else {
    Write-Log "MetaMod is already installed. Skipping MetaMod installation."
}

if (-not (Test-Path -Path "$gameDir/addons/sourcemod")) {
    Write-Log "Downloading SourceMod from $sourceModUrl"
    curl -fsSL --retry 3 --output /tmp/sourcemod.tar.gz "$sourceModUrl"
    if ($LASTEXITCODE -ne 0) { throw "Failed to download SourceMod from $sourceModUrl" }

    Write-Log "Extracting SourceMod to $gameDir"
    tar -xzf /tmp/sourcemod.tar.gz -C $gameDir
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract SourceMod" }
} else {
    Write-Log "SourceMod is already installed. Skipping SourceMod installation."
}

# The Fistful of Frags server is 32-bit (srcds_linux), so metamod.vdf loads Metamod:Source.
# The 64-bit loader entry in metamod_x64.vdf only produces a "wrong ELF class" load error.
Remove-Item -Path "$gameDir/addons/metamod_x64.vdf" -Force -ErrorAction SilentlyContinue

chown -R "${Env:UID}:${Env:GID}" $gameDir
if ($LASTEXITCODE -ne 0) { throw "Failed to set ownership of $gameDir" }

Invoke-Hook "PostInstallSourceMod"