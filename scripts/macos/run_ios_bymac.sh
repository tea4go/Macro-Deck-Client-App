#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上构建 development Web 资源、同步 iOS，并运行到模拟器/设备。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

write_banner "运行 iOS（macOS）"
echo
require_command xcodebuild

echo
ionic_build development
echo
cap_sync ios

echo
cd_root
print_command "npx cap run ios $*"
npx cap run ios "$@"
