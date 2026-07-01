#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上卸载 Homebrew 安装的 Ruby（install_2 的逆操作）。
# 用法：
#   ./scripts/macos/remove_3_ruby_bymac.sh [-y]

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

write_banner "Ruby 卸载（macOS）" 31
echo

if ! brew_command >/dev/null 2>&1; then
  write_warn "未检测到 Homebrew，无法判断/卸载 Homebrew Ruby"
  exit 0
fi

if ! brew list ruby >/dev/null 2>&1; then
  write_warn "未检测到 Homebrew 安装的 ruby"
  write_ok "不会卸载 macOS 系统 Ruby"
  exit 0
fi

write_warn "将卸载 Homebrew ruby，并可能影响依赖该 Ruby 的本地工具。"
if [ "$YES" != "true" ] && ! confirm_remove "Homebrew ruby"; then
  write_warn "已取消卸载"
  exit 0
fi

print_command "brew uninstall ruby"
brew uninstall ruby
write_ok "Homebrew ruby 已卸载"
