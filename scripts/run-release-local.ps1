#!/usr/bin/env pwsh
# Full local release pipeline test on Windows (includes protect)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Engine = if ($env:ENGINE_BIN) { $env:ENGINE_BIN } else {
    Join-Path $Root '../maxgame-release-tools/target/release/maxgame-release.exe'
}
$Config = Join-Path $Root 'release.config.json'
$Tag = if ($args.Count -gt 0) { $args[0] } else { 'v0.1.0-dev' }
$Channel = if ($args.Count -gt 1) { $args[1] } else { 'dev' }
# Game name is release-tools-internal config (GAME_NAME env / the workflow
# `game_name` input) — no longer read from release.config.json.
if (-not $env:GAME_NAME) { $env:GAME_NAME = 'mock-window-game' }

Write-Host "=== mock-window-game Windows release test ==="
Write-Host "engine: $Engine"
Write-Host "tag:    $Tag"

if (-not (Test-Path $Engine)) {
    Write-Host "Building maxgame-release..."
    Push-Location (Join-Path $Root '../maxgame-release-tools')
    cargo build --release
    Pop-Location
    $Engine = Join-Path $Root '../maxgame-release-tools/target/release/maxgame-release.exe'
}

Push-Location $Root
try {
    # Build the real game binary from game/ crate into fixtures/mock-game/game.exe
    & (Join-Path $Root 'scripts/build-mock-game.ps1')

    Write-Host '--- resolve ---'
    & $Engine resolve $Tag --config=$Config --format=env

    # The release tool does not build the game; it packs a prebuilt build/ dir.
    # Stage build/ from the fixture to stand in for the game's build output.
    Write-Host '--- stage build/ (fixture -> build/) ---'
    Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path build | Out-Null
    Copy-Item fixtures/mock-game/game.exe build/game.exe
    Copy-Item -Recurse fixtures/mock-game/assets build/assets

    Write-Host '--- inject-version ---'
    & $Engine inject-version --source=build/assets --tag=$Tag --channel=$Channel

    Write-Host '--- protect ---'
    & $Engine protect --config=$Config --tag=$Tag --build-dir=build --output-dir=output

    Write-Host '--- manifest ---'
    & $Engine manifest --config=$Config --tag=$Tag --artifact=output/MockWindowGame.exe --output-dir=output

    Write-Host '=== done ==='
    Get-ChildItem output
} finally {
    Pop-Location
}
