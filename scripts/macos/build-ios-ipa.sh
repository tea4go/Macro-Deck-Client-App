#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/common.sh"

require_command xcodebuild
require_command pod
require_command fastlane
require_env BUILD_NUMBER
require_env VERSION_NUMBER
require_env KEY_ID
require_env ISSUER_ID
require_env KEY_CONTENT
require_env MATCH_PASSWORD

ionic_build production
cap_sync ios

cd "$ROOT_DIR/ios/App"
pod install
fastlane build

echo "iOS IPA: $ROOT_DIR/ios/App/artifacts/macro-deck-client.ipa"
