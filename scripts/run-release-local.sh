#!/usr/bin/env bash
# Local release pipeline test.
#   windows lane (default): steps 1–5 + manifest; protect requires Windows
#   macos lane:             resolve → mock-build → inject → package (ditto) → manifest
# Usage: run-release-local.sh [tag] [channel] [platform]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="${ENGINE_BIN:-$ROOT/../maxgame-release-tools/target/debug/maxgame-release}"
CONFIG="$ROOT/release.config.json"
TAG="${1:-v0.1.0-dev}"
CHANNEL="${2:-dev}"
PLATFORM="${3:-windows}"

echo "=== mock-window-game local release test ==="
echo "root:     $ROOT"
echo "engine:   $ENGINE"
echo "tag:      $TAG"
echo "platform: $PLATFORM"
echo

if [[ ! -x "$ENGINE" ]]; then
  echo "Building maxgame-release..."
  (cd "$ROOT/../maxgame-release-tools" && cargo build -q)
  ENGINE="$ROOT/../maxgame-release-tools/target/debug/maxgame-release"
fi

cd "$ROOT"

if [[ "$PLATFORM" == "macos" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macos lane requires a macOS host (ditto)" >&2
    exit 1
  fi
  if [[ ! -d fixtures/mock-game-macos/MockWindowGame.app ]]; then
    echo "Generating mock .app fixture..."
    bash scripts/gen-mock-app.sh
  fi

  echo "--- resolve (macos) ---"
  "$ENGINE" resolve "$TAG" --config="$CONFIG" --format=env --platform=macos | head -6
  echo

  echo "--- mock-build (macos) ---"
  "$ENGINE" mock-build --config="$CONFIG" --output=build --platform=macos
  echo

  echo "--- inject-version ---"
  "$ENGINE" inject-version --source=build/MockWindowGame.app/Contents/Resources --tag="$TAG" --channel="$CHANNEL"
  echo

  echo "--- package (ditto) ---"
  "$ENGINE" package --config="$CONFIG" --build-dir=build --output-dir=output
  ARTIFACT=output/MockWindowGame-macos.zip
  echo

  echo "--- manifest (macos) ---"
  "$ENGINE" manifest --config="$CONFIG" --tag="$TAG" --artifact="$ARTIFACT" --output-dir=output --platform=macos
  echo

  echo "=== done (macos) ==="
  echo "output:"
  ls -la output/
  echo
  echo "manifest.json:"
  head -20 output/manifest.json
  exit 0
fi

# Ensure fixture game.exe exists
if [[ ! -f fixtures/mock-game/game.exe ]]; then
  echo "Generating minimal PE fixture..."
  python3 scripts/gen-minimal-pe.py
fi

echo "--- resolve ---"
"$ENGINE" resolve "$TAG" --config="$CONFIG" --format=env | head -5
echo

echo "--- mock-build ---"
"$ENGINE" mock-build --config="$CONFIG" --output=build
echo

echo "--- inject-version ---"
"$ENGINE" inject-version --source=build/assets --tag="$TAG" --channel="$CHANNEL"
echo

if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "${OS:-}" == Windows_NT ]]; then
  echo "--- protect (Windows) ---"
  "$ENGINE" protect --config="$CONFIG" --tag="$TAG" --build-dir=build --output-dir=output
  ARTIFACT=output/MockWindowGame.exe
else
  echo "--- protect (skipped on $(uname -s)) ---"
  mkdir -p output
  cp build/game.exe output/MockWindowGame.exe
  echo "copied build/game.exe → output/MockWindowGame.exe (stand-in for protect)"
  ARTIFACT=output/MockWindowGame.exe
fi

echo "--- manifest ---"
"$ENGINE" manifest --config="$CONFIG" --tag="$TAG" --artifact="$ARTIFACT" --output-dir=output
echo

echo "=== done ==="
echo "output:"
ls -la output/
echo
echo "manifest.json:"
head -20 output/manifest.json
