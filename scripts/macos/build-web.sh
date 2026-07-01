#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/common.sh"

CONFIGURATION="${CONFIGURATION:-web_production}"

ionic_build "$CONFIGURATION"

echo "Web build output: $ROOT_DIR/www"
