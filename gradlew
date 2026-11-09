#!/usr/bin/env sh

# Root gradlew delegating to Android client
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/src/android" && ./gradlew "$@"
