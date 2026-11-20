cask "kipir" do
  version "0.2.1"
  sha256 "f1e1c366611cf357281b3d41111c8de95608563070a1350887a0002567230338"

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
