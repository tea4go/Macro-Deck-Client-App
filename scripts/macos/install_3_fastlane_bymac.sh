#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上通过 Bundler 安装并检查 fastlane（基于仓库 Gemfile）。
# 用法：
#   ./scripts/macos/install_3_fastlane_bymac.sh [--check-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CHECK_ONLY="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--check-only]

  --check-only    只检查 Gemfile / Bundler / fastlane，不执行 bundle install
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

write_banner "fastlane 安装（macOS）"
echo

if [ ! -f "$ROOT_DIR/Gemfile" ]; then
  write_fail "未找到 Gemfile，无法用 Bundler 固定 fastlane 依赖"
  exit 1
fi

require_command bundle

if fastlane_command >/dev/null 2>&1; then
  write_ok "fastlane 调用方式：$(fastlane_command)"
  if [ "$CHECK_ONLY" = "true" ]; then
    exit 0
  fi
fi

if [ "$CHECK_ONLY" = "true" ]; then
  write_fail "未解析到 fastlane 调用方式"
  exit 1
fi

cd_root
print_command "bundle install"
bundle install

write_ok "fastlane 安装完成"
