#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上卸载 Android SDK 目录（install_4 的逆操作）。
# 用法：
#   ./scripts/macos/remove_1_android_sdk_bymac.sh [--sdk-root <path>] [-y]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

SDK_ROOT="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
YES="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--sdk-root <path>] [-y]

  --sdk-root    Android SDK 根目录，默认 ~/Library/Android/sdk
  -y            跳过卸载确认
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sdk-root)
      SDK_ROOT="${2:-}"
      shift 2
      ;;
    -y|--yes)
      YES="true"
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

write_banner "Android SDK 卸载（macOS）" 31
echo

if [ ! -d "$SDK_ROOT" ]; then
  write_warn "未找到 Android SDK 目录：$SDK_ROOT"
  write_ok "无需卸载"
  exit 0
fi

write_warn "将删除 Android SDK 目录：$SDK_ROOT"
if [ "$YES" != "true" ] && ! confirm_remove "Android SDK"; then
  write_warn "已取消卸载"
  exit 0
fi

print_command "rm -rf $SDK_ROOT"
rm -rf "$SDK_ROOT"
write_ok "Android SDK 目录已删除：$SDK_ROOT"
write_warn "如 ~/.zshrc 中配置了 ANDROID_HOME / ANDROID_SDK_ROOT / platform-tools PATH，请手动移除对应行。"
