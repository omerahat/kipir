# Kıpır — Homebrew ücretsiz önizleme dağıtımı

## Paket hazırlama

Xcode kurulu bir Mac'te depo kökünden:

```sh
bash Scripts/package-release.sh
```

Sürüm `Config.xcconfig` içindeki `MARKETING_VERSION` değerinden gelir. Betik mevcut
kaynakları (commit edilmemiş değişiklikler dahil) Release olarak Intel ve Apple
Silicon için derler; ad hoc imzayı ve iki mimariyi doğrular. Geliştirici sertifikası,
Apple hesabı veya yeni bağımlılık gerekmez. Derleme günlüğü:
`build/package-release.log`. Başarısız derlemede bu dosyayı inceleyin.

Çıktılar:

- `dist/Kipir-0.1.1.zip`: doğrudan Kipir.app içeren kurulum arşivi.
- `dist/Kipir-0.1.1.zip.sha256`: arşivin SHA-256 özeti.
- `dist/kipir.rb`: aynı sürüm, indirme adresi ve gerçek SHA-256 ile üretilen cask.
  İzlenen `Casks/kipir.rb` dosyası varsayılan olarak **değiştirilmez**; henüz
  yayımlanmamış bir ZIP'in özetini kendiliğinden depoya yazmamak için bu bilinçli bir
  adımdır. Üretilen cask'i inceledikten sonra `cp dist/kipir.rb Casks/kipir.rb` ile
  veya paketlemeyi baştan `WRITE_CASK=1 bash Scripts/package-release.sh` ile çalıştırarak
  kabul edin.

Betik aynı sürümün mevcut ZIP dosyasının üzerine yazmaz. Dağıtılmış bir sürümü
asla değiştirmeyin: yeni sürüm için MARKETING_VERSION ve CURRENT_PROJECT_VERSION
artırın ve yeniden paketleyin. Yayımlanmamış başarısız bir denemeyi tekrarlamak için
önce önceki yerel arşivi başka bir yere taşıyın. Üretilmiş cask ile ZIP daima aynı
paketleme çalışmasına ait olmalıdır; ZIP'i sonradan yeniden oluşturmayın.

## Yayımlama (ayrı onay gerektirir)

1. Mevcut değişiklikleri ve cask'i inceleyin; TESTING.md kontrollerini çalıştırın.
   Derleme çalışma ağacını paketler, otomatik commit/tag/push yapmaz.
2. Onaydan sonra ilgili kaynaklarla cask'i GitHub'daki `omerahat/kipir` deposunun
   varsayılan dalına gönderin. Deponun kullanıcılar tarafından erişilebilir olduğunu
   doğrulayın; özel depoda herkese açık kurulum mümkün değildir.
3. Paketlenen kaynak commit'ine `v0.1.1` etiketiyle bir GitHub Release oluşturun.
   `dist/Kipir-0.1.1.zip` ve `.zip.sha256` dosyalarını ekleyin. Cask adresi tam olarak:
   `https://github.com/omerahat/kipir/releases/download/v0.1.1/Kipir-0.1.1.zip`.
4. İndirilen arşivin özetini cask ile karşılaştırın. Ayrı bir Mac'te README'deki
   kurulum komutlarını deneyin. Henüz yayımlanmamış indirme adresini çalışır gibi
   duyurmayın. Sonraki sürümlerde aynı adımları yeni sürüm numarasıyla tekrarlayın.

## İki dağıtım yolu

| | Ücretsiz ad hoc önizleme | Developer ID + notarization |
|---|---|---|
| Betik | `Scripts/package-release.sh` | `Scripts/release-developer-id.sh` |
| Gereksinim | Xcode | Apple Developer Program üyeliği, Developer ID Application sertifikası, notarytool profili, Xcode |
| Gatekeeper | Onay yok; kullanıcı "Yine de Aç" yolunu izler | Noterli ve stapled uygulama normal açılır |
| Cask caveat'i | Noterlenmemiş uyarısı gerekir | Uyarı kaldırılmalı |

### Developer ID ve notarization (yalnızca bakımcı)

Ön koşullar (hiçbiri bu depoda veya betikte saklanmaz):

1. Ücretli Apple Developer Program üyeliği.
2. Oturum açma (login) anahtarlığında özel anahtarıyla birlikte bir **Developer ID
   Application** sertifikası. Kontrol: `security find-identity -v -p codesigning`.
3. Bakımcının bir kez oluşturduğu notarytool anahtarlık profili:
   `xcrun notarytool store-credentials <profil-adı>` (Apple Kimliği, takım kimliği ve
   uygulamaya özel parola etkileşimli girilir; betik parola görmez).
4. Xcode ve komut satırı araçları (`xcode-select -p`).

Yerel adım (Apple'a hiçbir şey göndermez):

```sh
export KIPIR_DEVELOPER_ID="Developer ID Application: Ad Soyad (TAKIMID)"
export KIPIR_NOTARY_PROFILE="<profil-adı>"
bash Scripts/release-developer-id.sh
```

Ortam değişkenleri yoksa betik `BLOCKED:` iletisiyle, derlemeden çıkar (çıkış kodu 2).
Kimlik anahtarlıkta yoksa yine derlemeden önce durur. Betik, proje imza ayarlarını
veya `Config.xcconfig` dosyasını değiştirmez; kimliği yalnızca xcodebuild komut satırı
geçersiz kılmalarıyla (`CODE_SIGN_IDENTITY`, `CODE_SIGN_STYLE=Manual`,
`OTHER_CODE_SIGN_FLAGS=--timestamp`) verir. Release yapılandırması projede zaten
`ENABLE_HARDENED_RUNTIME=YES` ve App Sandbox ile gelir.

Notarization (**Apple'a arşivi yükler**; yalnızca bakımcı, açık yetkiyle):

```sh
bash Scripts/release-developer-id.sh --notarize
```

Her adımın kanıtladığı:

| Adım | Kanıt |
|---|---|
| `codesign --verify --deep --strict` | Paket imzası bütün ve kurcalanmamış |
| `codesign -dvv` | İmza istenen Developer ID kimliğini, hardened runtime bayrağını ve güvenli zaman damgasını taşıyor; `get-task-allow` yok |
| `lipo -verify_arch` | Hem arm64 hem x86_64 içeriyor |
| `notarytool submit --wait` | Apple arşivi kabul etti (`status: Accepted`) |
| `stapler staple` / `validate` | Bilet pakete eklendi; çevrimdışı doğrulanabilir |
| `spctl -a -vv -t exec` | Yerel Gatekeeper değerlendirmesi `Notarized Developer ID` kaynağıyla kabul etti |

Uyarı: `--notarize` olmadan oluşan `dist/Kipir-<sürüm>-unnotarized.zip`
dağıtılmaz. Noterli son arşiv `dist/Kipir-<sürüm>.zip` ve `.sha256` olarak yazılır; mevcut
arşivlerin üzerine yazılmaz. Sürüm başına `package-release.sh` ve bu yol aynı ZIP adını
kullandığından biri çalıştıktan sonra diğeri için önceki arşivi taşıyın.

Bu ortamda engelli olanlar: Bu Mac'te Developer ID Application kimliği bulunmadığından
gerçek imzalama, notarization, staple ve `spctl` kabulü çalıştırılmadı; yalnızca
koruma yolları (BLOCKED, kimlik denetimi, arşiv koruması, derleme bayrakları) sahte
`security`/`xcodebuild` ile sınandı. Bu testler gerçek notarization veya Gatekeeper
kabulünü kanıtlamaz. Ayrı bir Mac'te indirilmiş noterli ZIP'in açılması insan/cihaz
kabulü olarak beklemededir.

### Homebrew cask uyumu

Noterli ZIP, mevcut cask yapısıyla (`app "Kipir.app"`, GitHub Release adresi, SHA-256)
aynen çalışır. Noterli sürüme geçerken `Casks/kipir.rb` içindeki "Apple tarafından
noterlenmemiştir / Yine de Aç" `caveats` metnini kaldırın; yalnızca menü çubuğu
bilgisini bırakın. Noterlenmemiş sürümlerde caveat'i koruyun. SHA-256 yalnızca son
noterli ZIP için hesaplanmalıdır (staple, ZIP'ten önce yapılır). Hiçbir durumda
quarantine silme veya Gatekeeper'ı devre dışı bırakma yönergesi verilmez.

## Kullanıcı kabulü

Bu paket **Apple tarafından noterlenmemiş, ad hoc imzalı bir önizlemedir**.
Homebrew indirme/kurulum sağlar; Gatekeeper onayı sağlamaz. Engelleme durumunda
Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç yolunu anlatın; quarantine
silme veya Gatekeeper'ı kapatma komutu vermeyin. Kurumsal politikalar açılışa izin
vermeyebilir. Normal dağıtım güveni için Developer ID ve notarization gerekir (yukarıdaki ikinci yol).

İndirilmiş kurulumda menü simgesi, bildirim izni/teslimi, açılışta başlatma,
uyku/uyanma, uygulamayı kapatıp yeniden açma ve güncellemede ayarların korunması
kontrol edilmelidir. Intel ve gerçek macOS 14 çalıştırma henüz doğrulanmış değildir.
Kaldırmadan önce Kıpır'ı kapatın ve etkinse Ayarlar'dan oturum açılışında başlatmayı
kapatın. Cask kullanıcı verisini silmez. Uygulamada otomatik güncelleyici yoktur;
güncelleme Homebrew üzerinden kullanıcının komutuyla yapılır.

Resmî kaynaklar: [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook),
[Tap rehberi](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap),
[Apple Developer ID](https://developer.apple.com/developer-id/).
