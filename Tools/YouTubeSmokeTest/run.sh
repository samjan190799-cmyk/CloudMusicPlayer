#!/usr/bin/env bash
# Запуск смоук-теста YouTube на macOS: ./Tools/YouTubeSmokeTest/run.sh
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SHARED="Sources/YouTubeSmokeTest/Shared"
mkdir -p "$SHARED"
cp "$ROOT/Sources/Services/YouTubeService.swift" "$SHARED/"
cp "$ROOT/Sources/Services/AudioFileSniffer.swift" "$SHARED/"
swift run -c release YouTubeSmokeTest "$@"
