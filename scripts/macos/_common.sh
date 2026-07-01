#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIN_NODE_MAJOR=18

color() {
  local code="$1"
  shift
  printf '\033[%sm%s\033[0m\n' "$code" "$*"
}

write_ok() {
  color 32 "  ✓  $*"
}

write_warn() {
  color 33 "  ⚠  $*"
}

write_fail() {
  color 31 "  ✗  $*"
}

write_info() {
  color 36 "$*"
}

write_banner() {
  local title="$1"
  local title_color="${2:-36}"
  local bar="══════════════════════════════════════════"
  color 36 "$bar"
  color "$title_color" "  $title"
  color 36 "$bar"
}

print_command() {
  color 36 "  运行命令：$*"
}

cd_root() {
  cd "$ROOT_DIR"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    write_fail "缺少必需命令: $command_name" >&2
    exit 1
  fi
  write_ok "$command_name 已安装：$(command -v "$command_name")"
}

require_env() {
  local env_name="$1"
  if [ -z "${!env_name:-}" ]; then
    write_fail "缺少必需环境变量: $env_name" >&2
    exit 1
  fi
  write_ok "$env_name 已设置"
}

confirm_remove() {
  local message="$1"
  local answer
  printf '  ? %s —— 是否卸载？ [y/N] ' "$message"
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

brew_command() {
  if command -v brew >/dev/null 2>&1; then
    printf 'brew'
    return
  fi
  return 1
}

test_nodejs() {
  if ! command -v node >/dev/null 2>&1; then
    write_fail "未找到 Node.js"
    write_fail "请从 https://nodejs.org/ 下载并安装 Node.js 20 LTS 或 22 LTS"
    return 1
  fi

  local version
  version="$(node --version)"
  local major="${version#v}"
  major="${major%%.*}"
  if [ "$major" -lt "$MIN_NODE_MAJOR" ]; then
    write_fail "检测到 Node.js $version，但需要 v18.19.1+ / v20.11.1+ / v22+"
    write_fail "请从 https://nodejs.org/ 安装 Node.js 20 LTS 或 22 LTS"
    return 1
  fi

  write_ok "Node.js $version 已安装：$(command -v node)"
}

test_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    write_fail "未找到 npm（通常随 Node.js 一起安装）"
    return 1
  fi
  write_ok "npm $(npm --version) 已安装：$(command -v npm)"
}

check_web_environment() {
  local failed=0

  write_info "[1/2] Node.js"
  test_nodejs || failed=1

  write_info "[2/2] npm"
  test_npm || failed=1

  if [ "$failed" -ne 0 ]; then
    echo
    write_banner "环境检查未通过，请修复以上问题后重试。" 31
    exit 1
  fi
}

clean_angular_cache() {
  cd_root
  if [ -d ".angular/cache" ]; then
    write_warn "正在删除 .angular/cache ..."
    print_command "npx ng cache clean"
    npx ng cache clean
    write_ok "Angular 构建缓存已清除"
  else
    write_ok ".angular/cache 不存在，无需清除"
  fi
}

ensure_node_modules() {
  cd_root
  if [ ! -d node_modules ]; then
    write_warn "node_modules 不存在，正在安装依赖 ..."
    print_command "npm install --legacy-peer-deps"
    npm install --legacy-peer-deps
    write_ok "npm install 完成"
    return 2
  fi
  write_ok "node_modules 已存在，跳过安装"
  return 0
}

assert_ajv_v8() {
  local pkg_json="$ROOT_DIR/node_modules/ajv/package.json"
  if [ ! -f "$pkg_json" ]; then
    return
  fi

  local major
  major="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)\..*/\1/p' "$pkg_json" | head -n 1)"
  if [ -z "$major" ]; then
    write_warn "无法解析 ajv 版本，跳过检查"
    return
  fi

  if [ "$major" -ge 8 ]; then
    write_ok "ajv v$major（已是 v8+）"
    return
  fi

  write_warn "检测到 ajv v$major 被提升到顶层（预期 v8+），正在自动修复 ..."
  print_command "npm install ajv@^8.20.0 --legacy-peer-deps"
  cd_root
  npm install 'ajv@^8.20.0' --legacy-peer-deps
  write_ok "ajv 已修复至 v8+"
}

prepare_web_build() {
  local clean="${1:-false}"
  local did_install=0

  write_banner "构建准备"
  echo

  write_info "[准备 1/2] npm 依赖"
  set +e
  ensure_node_modules
  local install_code=$?
  set -e
  if [ "$install_code" -eq 2 ]; then
    did_install=1
  elif [ "$install_code" -ne 0 ]; then
    exit "$install_code"
  fi

  write_info "[准备 2/2] ajv 版本检查"
  assert_ajv_v8

  if [ "$clean" = "true" ] || [ "$did_install" -eq 1 ]; then
    echo
    write_info "[清缓存] 清除 Angular 构建缓存"
    clean_angular_cache
  fi

  echo
  write_ok "构建准备完成！"
}

ionic_build() {
  local configuration="$1"
  cd_root
  prepare_web_build false
  echo
  write_banner "Web/PWA 构建（-c $configuration）"
  echo
  print_command "npx ionic build -c $configuration"
  echo
  npx ionic build -c "$configuration"
}

cap_sync() {
  local platform="$1"
  cd_root
  print_command "npx cap sync $platform"
  npx cap sync "$platform"
}

fastlane_command() {
  if command -v bundle >/dev/null 2>&1 && [ -f "$ROOT_DIR/Gemfile" ]; then
    printf 'bundle exec fastlane'
    return
  fi
  if command -v fastlane >/dev/null 2>&1; then
    printf 'fastlane'
    return
  fi
  return 1
}
