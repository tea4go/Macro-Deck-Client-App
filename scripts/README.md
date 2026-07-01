# Local scripts

These scripts avoid the npm peer dependency conflict by installing dependencies with `--legacy-peer-deps` when `node_modules` is missing.

## Setup

```bash
./scripts/macos/install_1_base_tools_bymac.sh
./scripts/macos/install_2_ruby_bymac.sh
./scripts/macos/install_3_fastlane_bymac.sh
./scripts/macos/install_4_android_sdk_bymac.sh
```

Windows PowerShell:

```powershell
.\scripts\windows\install_1_base_tools_bywin.ps1
```

## Run

```bash
./scripts/macos/run_web_bymac.sh
./scripts/macos/run_android_bymac.sh
./scripts/macos/run_ios_bymac.sh
```

Windows PowerShell:

```powershell
.\scripts\windows\build_web_bywin.ps1 dev
```

Pass Capacitor options after the script name, for example:

```bash
./scripts/macos/run_android_bymac.sh --target Pixel_8_API_35
./scripts/macos/run_ios_bymac.sh --target "iPhone 16"
```

## Build

Web:

```bash
./scripts/macos/build_web_bymac.sh build
```

```powershell
.\scripts\windows\build_web_bywin.ps1 build
```

Android signed release APK and AAB:

```bash
cp scripts/local/android-signing.env.example scripts/local/android-signing.env
vim scripts/local/android-signing.env
./scripts/macos/build_android_bymac.sh
```

At minimum, set `KEYSTORE_FILE_PASSWORD` in `scripts/local/android-signing.env`. The macOS script defaults to `~/keystore/macro-deck-client-keystore.jks`, alias `macro-deck-client`, and the current Android `versionCode`/`versionName`. Override them in the same file only when needed:

```bash
BUILD_NUMBER=3001
VERSION_NUMBER=3.0.0
KEYSTORE_FILE_PATH=/path/to/keystore.jks
KEYSTORE_FILE_ALIAS=your_alias
```

```powershell
copy scripts\local\android-signing.ps1.example scripts\local\android-signing.ps1
notepad scripts\local\android-signing.ps1
.\scripts\windows\build_android_bywin.ps1
```

At minimum, set `KEYSTORE_FILE_PASSWORD` in `scripts\local\android-signing.ps1`. The Windows script defaults to `%USERPROFILE%\keystore\macro-deck-client-keystore.jks`, alias `macro-deck-client`, and the current Android `versionCode`/`versionName`. Override them in the same file only when needed:

```powershell
$env:BUILD_NUMBER = '3001'
$env:VERSION_NUMBER = '3.0.0'
$env:KEYSTORE_FILE_PATH = 'C:\path\to\keystore.jks'
$env:KEYSTORE_FILE_ALIAS = 'your_alias'
```

## GitHub Actions Android signing

The Android workflow uses the same keystore values as local release builds, but stores them in GitHub Secrets instead of `scripts/local/*`.

Create these repository secrets:

- `ANDROID_KEYSTORE_BASE64`: base64 content of the local `.jks` file
- `ANDROID_KEYSTORE_PASSWORD`: the keystore password
- `ANDROID_KEYSTORE_KEY`: the key alias, default `macro-deck-client`

On macOS, generate the keystore secret value from the local default keystore:

```bash
base64 < ~/keystore/macro-deck-client-keystore.jks | tr -d '\n' | pbcopy
```

Paste the clipboard content into `ANDROID_KEYSTORE_BASE64`.

The workflow writes the decoded keystore to the runner and passes these values to fastlane:

```bash
KEYSTORE_FILE_PATH=$GITHUB_WORKSPACE/keystore.jks
KEYSTORE_FILE_PASSWORD=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
KEYSTORE_FILE_ALIAS=${{ secrets.ANDROID_KEYSTORE_KEY }}
```

The CI workflow now only builds Android artifacts. It does not deploy to Play Store or attach release assets.

iOS IPA:

```bash
export BUILD_NUMBER=3001
export VERSION_NUMBER=3.0.0
export KEY_ID=app_store_connect_key_id
export ISSUER_ID=app_store_connect_issuer_id
export KEY_CONTENT=app_store_connect_private_key_content
export MATCH_PASSWORD=match_repo_password
./scripts/macos/build_ios_ipa_bymac.sh
```

The iOS script requires macOS, Xcode command line tools, CocoaPods, fastlane, and access to the signing certificates configured by fastlane match.

## Remove

macOS:

```bash
./scripts/macos/remove_1_android_sdk_bymac.sh
./scripts/macos/remove_2_fastlane_bymac.sh
./scripts/macos/remove_3_ruby_bymac.sh
```

Windows PowerShell:

```powershell
.\scripts\windows\remove_1_android_sdk_bywin.ps1
.\scripts\windows\remove_2_fastlane_bywin.ps1
.\scripts\windows\remove_3_ruby_bywin.ps1
```
