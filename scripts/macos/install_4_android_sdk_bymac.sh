#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上安装/检查 Android SDK command-line tools，并配置当前会话环境变量。
# 用法：
#   ./scripts/macos/install_4_android_sdk_bymac.sh [--sdk-root <path>] [--check-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

SDK_ROOT="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
CHECK_ONLY="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--sdk-root <path>] [--check-only]

  --sdk-root       Android SDK 根目录，默认 ~/Library/Android/sdk
  --check-only     只检查 sdkmanager / adb，不执行安装
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sdk-root)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        write_fail "$1 需要一个目录路径"
        exit 1
      fi
      SDK_ROOT="$2"
      shift 2
      ;;
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

write_banner "Android SDK 安装（macOS）"
echo

export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

if command -v sdkmanager >/dev/null 2>&1; then
  write_ok "sdkmanager 已安装：$(command -v sdkmanager)"
elif [ "$CHECK_ONLY" = "true" ]; then
  write_fail "未检测到 sdkmanager"
  exit 1
else
  if brew_command >/dev/null 2>&1; then
    print_command "brew install --cask android-commandlinetools"
    brew install --cask android-commandlinetools
  else
    write_fail "缺少 sdkmanager，且无法通过 Homebrew 自动安装 android-commandlinetools"
    exit 1
  fi
fi

if [ "$CHECK_ONLY" = "true" ]; then
  require_command adb
  write_ok "Android SDK 检查完成"
  exit 0
fi

mkdir -p "$ANDROID_HOME"
print_command "sdkmanager platform-tools platforms;android-35 build-tools;35.0.0"
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

write_ok "Android SDK 安装完成：$ANDROID_HOME"
write_warn "如需新终端自动生效，请把以下内容加入 ~/.zshrc："
printf '  export ANDROID_HOME="%s"\n' "$ANDROID_HOME"
printf '  export ANDROID_SDK_ROOT="$ANDROID_HOME"\n'
printf '  export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"\n'
