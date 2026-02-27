#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backward-compatible wrapper.
exec "$SCRIPT_DIR/macforge" setup "$@"
