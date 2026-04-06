#!/bin/bash
# Build and run Kotlin server

cd "$(dirname "$0")"

# First ensure build runs
./gradlew build

# Then run
java -jar build/libs/claude-mobile-server.jar "$@"
