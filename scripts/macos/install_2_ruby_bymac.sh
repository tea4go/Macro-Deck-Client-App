#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上检测并安装 Ruby 与 Bundler（fastlane 的运行环境）。
# 用法：
#   ./scripts/macos/install_2_ruby_bymac.sh [--check-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CHECK_ONLY="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--check-only]

  --check-only    只检查 Ruby / Bundler，不执行安装
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only|-CheckOnly)
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

write_banner "Ruby 安装（macOS）"
echo

ruby_ok="false"
if command -v ruby >/dev/null 2>&1; then
  ruby_version="$(ruby -e 'print RUBY_VERSION' 2>/dev/null || true)"
  ruby_major="${ruby_version%%.*}"
  if [ -n "$ruby_major" ] && [ "$ruby_major" -ge 3 ]; then
    ruby_ok="true"
    write_ok "Ruby $ruby_version 已安装：$(command -v ruby)"
  else
    write_warn "检测到 Ruby ${ruby_version:-unknown}；fastlane 建议 Ruby 3.0+"
  fi
else
  write_warn "未检测到 Ruby"
fi

if [ "$ruby_ok" != "true" ]; then
  if [ "$CHECK_ONLY" = "true" ]; then
    exit 1
  fi
  if brew_command >/dev/null 2>&1; then
    print_command "brew install ruby"
    brew install ruby
  else
    write_fail "缺少 Ruby 3.0+，且无法通过 Homebrew 自动安装"
    exit 1
  fi
fi

if command -v bundle >/dev/null 2>&1; then
  write_ok "Bundler 已安装：$(command -v bundle)"
elif [ "$CHECK_ONLY" = "true" ]; then
  write_fail "未检测到 Bundler"
  exit 1
else
  print_command "gem install bundler"
  gem install bundler
fi

write_ok "Ruby / Bundler 检查完成"
