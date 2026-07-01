#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上检查环境并构建 Ionic Web/PWA、预览构建产物，或启动开发服务器。
# 用法：
#   ./scripts/macos/build_web_bymac.sh <build|dev|serve|check> [--configuration <config>] [--clean] [--port <n>]
# 默认命令为 build，默认构建配置为 web_production。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

COMMAND="build"
CONFIGURATION="${CONFIGURATION:-web_production}"
CLEAN="false"
PORT=8080

usage() {
  cat <<EOF
用法：$(basename "$0") <build|dev|serve|check> [--configuration <config>] [--clean] [--port <n>]

  build             构建 Web/PWA 产物（输出到 www/）
  dev               启动本地开发服务器（热重载，Ctrl+C 退出）
  serve             用 http-server 预览 www/ 构建产物（Ctrl+C 退出）
  check             仅检查环境，不执行构建
  --configuration   Angular 构建配置（默认 web_production）
                    可选：web_production | production | development
  --clean           构建前清除 Angular 缓存（.angular/cache）
  --port            serve 命令的监听端口（默认 8080）
EOF
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    build|dev|serve|check)
      COMMAND="$1"
      shift
      ;;
  esac
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --configuration|-c)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        write_fail "$1 需要一个构建配置"
        usage
        exit 1
      fi
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --clean)
      CLEAN="true"
      shift
      ;;
    --port|-p)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        write_fail "$1 需要一个端口号"
        usage
        exit 1
      fi
      PORT="${2:-}"
      shift 2
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

case "$CONFIGURATION" in
  web_production|production|development) ;;
  *)
    write_fail "不支持的构建配置: $CONFIGURATION"
    usage
    exit 1
    ;;
esac

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  write_fail "端口号必须是数字: $PORT"
  usage
  exit 1
fi

write_banner "Web 构建环境检查（macOS）"
echo
check_web_environment

echo
if [ "$COMMAND" = "check" ]; then
  write_banner "所有检查通过！" 32
  echo
  exit 0
fi

if [ "$COMMAND" = "serve" ]; then
  WWW_DIR="$ROOT_DIR/www"
  if [ ! -f "$WWW_DIR/index.html" ]; then
    write_fail "未找到构建产物 www/index.html，请先运行：./scripts/macos/build_web_bymac.sh build"
    exit 1
  fi

  SERVE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mdc-serve.XXXXXX")"
  cleanup() {
    rm -rf "$SERVE_ROOT"
    echo
    write_ok "已清理临时托管目录"
  }
  trap cleanup EXIT
  ln -s "$WWW_DIR" "$SERVE_ROOT/client"

  write_banner "预览构建产物（Ctrl+C 退出）"
  echo
  write_ok "访问地址：http://localhost:$PORT/client/"
  print_command "npx http-server <临时目录> -p $PORT -c-1"
  echo
  cd_root
  npx -y http-server "$SERVE_ROOT" -p "$PORT" -c-1
  exit $?
fi

prepare_web_build "$CLEAN"
echo

if [ "$COMMAND" = "dev" ]; then
  write_banner "启动本地开发服务器（Ctrl+C 退出）"
  echo
  print_command "npx ionic serve"
  echo
  cd_root
  npx ionic serve
  exit $?
fi

write_banner "Web/PWA 构建（-c $CONFIGURATION）"
echo
print_command "npx ionic build -c $CONFIGURATION"
echo
cd_root
npx ionic build -c "$CONFIGURATION"

echo
write_banner "构建成功！" 32
write_ok "Web 产物目录：$ROOT_DIR/www"
if [ -f "$ROOT_DIR/www/index.html" ]; then
  write_ok "index.html 已生成"
fi
