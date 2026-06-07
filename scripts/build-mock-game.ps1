#!/usr/bin/env pwsh
# Build fixtures/mock-game/game.exe from game/ crate (Windows)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$GameDir = Join-Path $Root 'game'
$Out = Join-Path $Root 'fixtures/mock-game/game.exe'

Push-Location $GameDir
try {
    cargo build --release
    $built = Join-Path $GameDir 'target/release/game.exe'
    if (-not (Test-Path $built)) { throw "game.exe not built" }
    Copy-Item $built $Out -Force
    Write-Host "✓ fixture game.exe → $Out"
} finally {
    Pop-Location
}
