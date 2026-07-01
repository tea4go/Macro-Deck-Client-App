#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上检测并安装基础工具与项目依赖。
# 主要流程：
# - 检查 Homebrew、Node.js / npm
# - Homebrew 可用且 Node.js 缺失时，自动安装 Node.js
# - 使用 npm install --legacy-peer-deps 安装依赖，避开 peer dependency 冲突

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CHECK_ONLY="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--check-only]

  --check-only    只检查 Homebrew / Node.js / npm，不安装工具或项目依赖
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

write_banner "基础工具安装（macOS）"
echo

write_info "[1/3] Homebrew"
if brew_command >/dev/null 2>&1; then
  write_ok "Homebrew 已安装：$(command -v brew)"
else
  write_warn "未检测到 Homebrew；如需自动安装 Node.js，请先安装 Homebrew: https://brew.sh/"
fi

write_info "[2/3] Node.js / npm"
if ! test_nodejs || ! test_npm; then
  if [ "$CHECK_ONLY" = "true" ]; then
    exit 1
  fi
  if brew_command >/dev/null 2>&1; then
    print_command "brew install node"
    brew install node
  else
    write_fail "缺少 Node.js，且无法通过 Homebrew 自动安装"
    exit 1
  fi
  test_nodejs
  test_npm
fi

write_info "[3/3] 项目 npm 依赖"
if [ "$CHECK_ONLY" = "true" ]; then
  write_ok "基础工具检查完成"
  exit 0
fi

echo
cd_root
print_command "npm install --legacy-peer-deps"
npm install --legacy-peer-deps
write_ok "npm install 完成"
