cask "kipir" do
  version "0.1.0"
  sha256 "fb3959f8453b80d2bb5cd9342914e3baaa887f802498d38d3e22eea621fb7cb9"

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
