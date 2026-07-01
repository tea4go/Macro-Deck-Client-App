#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上卸载 fastlane gem（install_3 的逆操作）。
# 用法：
#   ./scripts/macos/remove_2_fastlane_bymac.sh [-y]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

YES="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      YES="true"
      shift
      ;;
    --help|-h)
      printf '用法：%s [-y]\n' "$(basename "$0")"
      exit 0
      ;;
    *)
      write_fail "未知参数: $1"
      exit 1
      ;;
  esac
done

write_banner "fastlane 卸载（macOS）" 31
echo

if ! command -v gem >/dev/null 2>&1; then
  write_warn "未检测到 gem（Ruby 可能已卸载）"
  write_ok "fastlane 无需单独卸载"
  exit 0
fi

if [ "$(gem list -i '^fastlane$' 2>/dev/null | tr -d '[:space:]')" != "true" ]; then
  write_warn "未检测到已安装的 fastlane gem"
  write_ok "无需卸载"
  exit 0
fi

if [ "$YES" != "true" ] && ! confirm_remove "fastlane gem（全部版本及其可执行文件）"; then
  write_warn "已取消卸载"
  exit 0
fi

print_command "gem uninstall fastlane --all --ignore-dependencies --executables"
gem uninstall fastlane --all --ignore-dependencies --executables
write_ok "fastlane gem 已卸载"
