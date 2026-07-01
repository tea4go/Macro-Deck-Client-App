#!/usr/bin/env bash
set -euo pipefail

# 在 macOS 上构建 Ionic + Capacitor 的 Android 发布产物（release APK/AAB），并完成签名环境校验。
# 主要流程：
# 1) 加载 scripts/local/android-signing.env 中的本地签名变量（keystore 密码等）
# 2) 校验签名环境：未设置的 BUILD_NUMBER/VERSION_NUMBER 自动从 android/app/build.gradle 读取
# 3) 用 Ionic production 配置构建 Web 资源，再执行 Capacitor Android sync
# 4) 在 android 目录下通过 bundle exec fastlane build 产出 APK/AAB
# 用法：
#   ./scripts/macos/build_android_bymac.sh [--check]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

ANDROID_SIGNING_ENV_FILE="$ROOT_DIR/scripts/local/android-signing.env"
DEFAULT_KEYSTORE_FILE_PATH="$HOME/keystore/macro-deck-client-keystore.jks"
DEFAULT_KEYSTORE_FILE_ALIAS="macro-deck-client"
CHECK_ONLY="false"

usage() {
  cat <<EOF
用法：$(basename "$0") [--check]

  --check    只检查签名变量、npx、fastlane 是否可用，不执行 Web/Android 构建
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

load_android_signing_env() {
  if [ -f "$ANDROID_SIGNING_ENV_FILE" ]; then
    write_ok "已加载签名变量文件：$ANDROID_SIGNING_ENV_FILE"
    set -a
    # shellcheck disable=SC1090
    source "$ANDROID_SIGNING_ENV_FILE"
    set +a
  else
    write_warn "未找到签名变量文件：$ANDROID_SIGNING_ENV_FILE"
  fi
}

read_android_gradle_value() {
  local key="$1"
  sed -n "s/^[[:space:]]*$key[[:space:]]*//p" "$ROOT_DIR/android/app/build.gradle" | head -n 1 | tr -d '"'
}

require_fastlane() {
  if fastlane_command >/dev/null 2>&1; then
    write_ok "fastlane 调用方式：$(fastlane_command)"
    return
  fi

  cat >&2 <<'EOF'
缺少必需命令: fastlane

构建 Android release 产物前，请先安装 fastlane。

macOS 推荐方式：
  brew install fastlane

或使用 RubyGems：
  sudo gem install fastlane

如果使用仓库 Gemfile 固定 fastlane 版本：
  bundle install

然后重新运行：
  ./scripts/macos/build_android_bymac.sh
EOF
  exit 1
}

print_android_signing_help() {
  if [ -f "${KEYSTORE_FILE_PATH:-$DEFAULT_KEYSTORE_FILE_PATH}" ]; then
    cat >&2 <<EOF

Android release builds require a signing keystore.

Found the keystore:
  ${KEYSTORE_FILE_PATH:-$DEFAULT_KEYSTORE_FILE_PATH}

Add the keystore password to:
  $ANDROID_SIGNING_ENV_FILE

Example:
  KEYSTORE_FILE_PASSWORD="your_keystore_password"

Optional overrides:
  BUILD_NUMBER="${BUILD_NUMBER:-$(read_android_gradle_value versionCode)}"
  VERSION_NUMBER="${VERSION_NUMBER:-$(read_android_gradle_value versionName)}"
  KEYSTORE_FILE_PATH="${KEYSTORE_FILE_PATH:-$DEFAULT_KEYSTORE_FILE_PATH}"
  KEYSTORE_FILE_ALIAS="${KEYSTORE_FILE_ALIAS:-$DEFAULT_KEYSTORE_FILE_ALIAS}"

Run:
  ./scripts/macos/build_android_bymac.sh

Do not commit keystore files or passwords to git.
EOF
  else
    cat >&2 <<EOF

Android release builds require a signing keystore.

Create a local keystore if you do not have one:
  keytool -genkey -v \
    -keystore "$DEFAULT_KEYSTORE_FILE_PATH" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias $DEFAULT_KEYSTORE_FILE_ALIAS

Then save the keystore password before running this script:
  KEYSTORE_FILE_PASSWORD="your_keystore_password"

Optional overrides:
  BUILD_NUMBER="${BUILD_NUMBER:-$(read_android_gradle_value versionCode)}"
  VERSION_NUMBER="${VERSION_NUMBER:-$(read_android_gradle_value versionName)}"
  KEYSTORE_FILE_PATH="$DEFAULT_KEYSTORE_FILE_PATH"
  KEYSTORE_FILE_ALIAS="$DEFAULT_KEYSTORE_FILE_ALIAS"

Save these values in:
  $ANDROID_SIGNING_ENV_FILE

Run:
  ./scripts/macos/build_android_bymac.sh

Do not commit keystore files or passwords to git.
EOF
  fi
}

require_android_release_env() {
  local missing=()
  local env_name

  export BUILD_NUMBER="${BUILD_NUMBER:-$(read_android_gradle_value versionCode)}"
  export VERSION_NUMBER="${VERSION_NUMBER:-$(read_android_gradle_value versionName)}"
  export KEYSTORE_FILE_PATH="${KEYSTORE_FILE_PATH:-$DEFAULT_KEYSTORE_FILE_PATH}"
  export KEYSTORE_FILE_ALIAS="${KEYSTORE_FILE_ALIAS:-$DEFAULT_KEYSTORE_FILE_ALIAS}"

  for env_name in \
    BUILD_NUMBER \
    VERSION_NUMBER \
    KEYSTORE_FILE_PASSWORD
  do
    if [ -z "${!env_name:-}" ]; then
      missing+=("$env_name")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    write_fail "缺少必需环境变量: ${missing[*]}" >&2
    print_android_signing_help
    exit 1
  fi

  if [ ! -f "$KEYSTORE_FILE_PATH" ]; then
    write_fail "Keystore 文件不存在: $KEYSTORE_FILE_PATH" >&2
    print_android_signing_help
    exit 1
  fi

  write_ok "BUILD_NUMBER=$BUILD_NUMBER"
  write_ok "VERSION_NUMBER=$VERSION_NUMBER"
  write_ok "KEYSTORE_FILE_PATH=$KEYSTORE_FILE_PATH"
  write_ok "KEYSTORE_FILE_ALIAS=$KEYSTORE_FILE_ALIAS"
}

write_banner "构建 Android release（macOS）"
echo

load_android_signing_env
require_android_release_env
require_command npx
require_fastlane

if [ "$CHECK_ONLY" = "true" ]; then
  echo
  write_banner "Android release 环境检查通过" 32
  exit 0
fi

echo
ionic_build production
echo
cap_sync android

echo
cd "$ROOT_DIR/android"
FASTLANE_CMD="$(fastlane_command)"
print_command "$FASTLANE_CMD build"
if [ "$FASTLANE_CMD" = "bundle exec fastlane" ]; then
  bundle exec fastlane build
else
  fastlane build
fi

echo
write_banner "Android release 构建成功！" 32
write_ok "Android release APK 产物: $ROOT_DIR/android/app/build/outputs/apk/release/app-release.apk"
write_ok "Android release AAB 产物: $ROOT_DIR/android/app/build/outputs/bundle/release/app-release.aab"
