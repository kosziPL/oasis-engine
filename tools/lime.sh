#!/usr/bin/env bash
set -euo pipefail

# VS Code launched from the desktop does not have the project's Lix tools in PATH.
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$PROJECT_DIR/node_modules/.bin:$PATH"
cd -- "$PROJECT_DIR"
exec haxelib run lime "$@"
