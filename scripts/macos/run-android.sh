#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/common.sh"

require_command npx
require_command adb

ionic_build development
cap_sync android

cd_root
npx cap run android --no-sync "$@"
