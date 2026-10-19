#!/usr/bin/env bash
# Kör regelmotorns enhetstester. På en Mac räcker `swift test` i Engine/.
# Utan Swift installerat (t.ex. i Linux) körs testerna i Swifts Docker-image.
set -euo pipefail
cd "$(dirname "$0")/../Engine"

if command -v swift >/dev/null 2>&1; then
  exec swift test "$@"
fi

IMAGE="${SWIFT_DOCKER_IMAGE:-swift:6.1}"
exec docker run --rm -v "$PWD":/engine -w /engine "$IMAGE" swift test "$@"
