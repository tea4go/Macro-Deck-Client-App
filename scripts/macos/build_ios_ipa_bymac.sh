#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上构建 Ionic + Capacitor 的 iOS IPA，并完成 fastlane/match 所需环境校验。
# 用法：
#   ./scripts/macos/build_ios_ipa_bymac.sh [--check]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CHECK_ONLY="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--check]

  --check    只检查 Xcode/CocoaPods/fastlane 与签名环境变量，不执行构建
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check|-Check)
      CHECK_ONLY="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      write_fail "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

write_banner "构建 iOS IPA（macOS）"
echo

require_command xcodebuild
require_command pod
if fastlane_command >/dev/null 2>&1; then
  write_ok "fastlane 调用方式：$(fastlane_command)"
else
  write_fail "缺少必需命令: fastlane"
  exit 1
fi
require_env BUILD_NUMBER
require_env VERSION_NUMBER
require_env KEY_ID
require_env ISSUER_ID
require_env KEY_CONTENT
require_env MATCH_PASSWORD

if [ "$CHECK_ONLY" = "true" ]; then
  echo
  write_banner "iOS IPA 环境检查通过" 32
  exit 0
fi

echo
ionic_build production
echo
cap_sync ios

echo
cd "$ROOT_DIR/ios/App"
print_command "pod install"
pod install
FASTLANE_CMD="$(fastlane_command)"
print_command "$FASTLANE_CMD build"
if [ "$FASTLANE_CMD" = "bundle exec fastlane" ]; then
  bundle exec fastlane build
else
  fastlane build
fi

echo
write_banner "iOS IPA 构建成功！" 32
write_ok "iOS IPA 产物: $ROOT_DIR/ios/App/artifacts/macro-deck-client.ipa"
