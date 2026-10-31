cask "kipir" do
  version "0.1.1"
  sha256 "35fe95418a6bb27428a71e70298f41278212918410caffc8b79bb24b1d27d6e3"

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
