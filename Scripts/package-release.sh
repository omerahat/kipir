#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -ne 0 ]]; then
  echo "Usage: bash Scripts/package-release.sh (version comes from Config.xcconfig)" >&2
  exit 1
fi
version=$(sed -nE 's/^MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' Config.xcconfig)
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Config.xcconfig must contain a three-part MARKETING_VERSION." >&2
  exit 1
fi
archive="dist/Kipir-${version}.zip"
if [[ -e "$archive" ]]; then
  echo "Refusing to overwrite $archive. Bump the version or move the previous artifact first." >&2
  exit 1
fi
mkdir -p dist Casks build
xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Release \
  -derivedDataPath build COMPILER_INDEX_STORE_ENABLE=NO ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES \
  build > build/package-release.log 2>&1
app="build/Build/Products/Release/Kipir.app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/lipo "$app/Contents/MacOS/Kipir" -verify_arch arm64 x86_64
actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$actual_version" == "$version" ]]
# shortcut: ad hoc signing supports the free preview; use Developer ID and notarization for trusted public releases.
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
sha256=$(/usr/bin/shasum -a 256 "$archive" | awk '{print $1}')
printf '%s  %s\n' "$sha256" "Kipir-${version}.zip" > "${archive}.sha256"
cat > Casks/kipir.rb <<CASK
cask "kipir" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/omerahat/kipir/releases/download/v#{version}/Kipir-#{version}.zip"
  name "Kıpır"
  desc "Private movement reminders in the menu bar"
  homepage "https://github.com/omerahat/kipir"

  depends_on macos: :sonoma

  app "Kipir.app"

  caveats <<~EOS
    Bu ücretsiz önizleme Apple tarafından noterlenmemiştir.
    İlk açılışta macOS engellerse Sistem Ayarları > Gizlilik ve Güvenlik
    bölümündeki Yine de Aç seçeneğini kullanabilirsiniz.
    Kıpır yalnızca menü çubuğunda görünür; yürüyen kişi simgesine tıklayın.
  EOS
end
CASK
printf 'Prepared %s and Casks/kipir.rb (not published).\n' "$archive"
