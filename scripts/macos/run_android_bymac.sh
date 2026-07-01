#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上构建 development Web 资源、同步 Android，并运行到设备/模拟器。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

write_banner "运行 Android（macOS）"
echo
require_command npx
require_command adb

echo
ionic_build development
echo
cap_sync android

echo
cd_root
print_command "npx cap run android --no-sync $*"
npx cap run android --no-sync "$@"
