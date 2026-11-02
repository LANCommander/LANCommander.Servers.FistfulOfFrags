#Requires -Modules Logging
#Requires -Modules SteamCMD

# On a fresh SteamCMD (no cached app info), installing some Source dedicated servers
# fails with "Missing configuration". For the first install, refresh the app info
# (app_info_update) and install in the same session; after the app manifest exists,
# the regular install/update run by 20-InstallGame.ps1 works.

$manifest = Join-Path $Env:SERVER_DIR "steamapps/appmanifest_${Env:STEAM_APP_ID}.acf"

if (Test-Path -Path $manifest) {
    return
}

Write-Log "No app manifest for $Env:STEAM_APP_ID yet. Bootstrapping the install."

New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null

$steamCmdArgs = @(
    "+@ShutdownOnFailedCommand", "1",
    "+@NoPromptForPassword", "1",
    "+force_install_dir", $Env:SERVER_DIR,
    "+login", $Env:STEAM_USERNAME
)

if ($Env:STEAM_USERNAME -ne "anonymous" -and $Env:STEAM_PASSWORD) {
    $steamCmdArgs += $Env:STEAM_PASSWORD
}

$steamCmdArgs += "+app_info_update", "1", "+app_update", $Env:STEAM_APP_ID

if ($Env:STEAM_BRANCH) {
    $steamCmdArgs += "-beta", $Env:STEAM_BRANCH
    if ($Env:STEAM_BRANCH_PASSWORD) {
        $steamCmdArgs += "-betapassword", $Env:STEAM_BRANCH_PASSWORD
    }
}

$steamCmdArgs += "validate", "+quit"

for ($attempt = 1; $attempt -le 3; $attempt++) {
    Invoke-SteamCmd -Arguments $steamCmdArgs

    if (Test-Path -Path $manifest) {
        chown -R "${Env:UID}:${Env:GID}" $Env:SERVER_DIR
        if ($LASTEXITCODE -ne 0) { throw "Failed to set ownership of $Env:SERVER_DIR" }

        Write-Log "Bootstrap install finished."
        return
    }

    Write-Log "Bootstrap install attempt $attempt did not complete. Retrying."
}

throw "Failed to bootstrap the install of app $Env:STEAM_APP_ID"
