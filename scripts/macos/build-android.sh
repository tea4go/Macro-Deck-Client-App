#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/common.sh"

ANDROID_SIGNING_ENV_FILE="$ROOT_DIR/scripts/local/android-signing.env"
DEFAULT_KEYSTORE_FILE_PATH="$HOME/keystore/macro-deck-client-keystore.jks"
DEFAULT_KEYSTORE_FILE_ALIAS="macro-deck-client"

load_android_signing_env() {
  if [ -f "$ANDROID_SIGNING_ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ANDROID_SIGNING_ENV_FILE"
    set +a
  fi
}

read_android_gradle_value() {
  local key="$1"
  sed -n "s/^[[:space:]]*$key[[:space:]]*//p" "$ROOT_DIR/android/app/build.gradle" | head -n 1 | tr -d '"'
}

require_fastlane() {
  if command -v fastlane >/dev/null 2>&1; then
    return
  fi

  cat >&2 <<'EOF'
Missing required command: fastlane

Install fastlane before building Android release artifacts.

Recommended on macOS with Homebrew:
  brew install fastlane

Alternative with RubyGems:
  sudo gem install fastlane

Then run again:
  ./scripts/unix/build-android.sh
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
  ./scripts/unix/build-android.sh

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
  ./scripts/unix/build-android.sh

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
    echo "Missing required environment variable(s): ${missing[*]}" >&2
    print_android_signing_help
    exit 1
  fi

  if [ ! -f "$KEYSTORE_FILE_PATH" ]; then
    echo "Keystore file does not exist: $KEYSTORE_FILE_PATH" >&2
    print_android_signing_help
    exit 1
  fi
}

load_android_signing_env
require_android_release_env
require_command npx
require_fastlane

ionic_build production
cap_sync android

cd "$ROOT_DIR/android"
fastlane build

echo "Android release APK: $ROOT_DIR/android/app/build/outputs/apk/release/app-release.apk"
echo "Android release AAB: $ROOT_DIR/android/app/build/outputs/bundle/release/app-release.aab"
