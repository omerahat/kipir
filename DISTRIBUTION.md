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

- `dist/Kipir-0.1.0.zip`: doğrudan Kipir.app içeren kurulum arşivi.
- `dist/Kipir-0.1.0.zip.sha256`: arşivin SHA-256 özeti.
- `Casks/kipir.rb`: aynı sürüm, indirme adresi ve gerçek SHA-256 ile güncellenir.

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
3. Paketlenen kaynak commit'ine `v0.1.0` etiketiyle bir GitHub Release oluşturun.
   `dist/Kipir-0.1.0.zip` ve `.zip.sha256` dosyalarını ekleyin. Cask adresi tam olarak:
   `https://github.com/omerahat/kipir/releases/download/v0.1.0/Kipir-0.1.0.zip`.
4. İndirilen arşivin özetini cask ile karşılaştırın. Ayrı bir Mac'te README'deki
   kurulum komutlarını deneyin. Henüz yayımlanmamış indirme adresini çalışır gibi
   duyurmayın. Sonraki sürümlerde aynı adımları yeni sürüm numarasıyla tekrarlayın.

## Kullanıcı kabulü

Bu paket **Apple tarafından noterlenmemiş, ad hoc imzalı bir önizlemedir**.
Homebrew indirme/kurulum sağlar; Gatekeeper onayı sağlamaz. Engelleme durumunda
Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç yolunu anlatın; quarantine
silme veya Gatekeeper'ı kapatma komutu vermeyin. Kurumsal politikalar açılışa izin
vermeyebilir. Normal dağıtım güveni için ileride Developer ID ve notarization gerekir.

İndirilmiş kurulumda menü simgesi, bildirim izni/teslimi, açılışta başlatma,
uyku/uyanma, uygulamayı kapatıp yeniden açma ve güncellemede ayarların korunması
kontrol edilmelidir. Intel ve gerçek macOS 14 çalıştırma henüz doğrulanmış değildir.
Kaldırmadan önce Kıpır'ı kapatın ve etkinse Ayarlar'dan oturum açılışında başlatmayı
kapatın. Cask kullanıcı verisini silmez. Uygulamada otomatik güncelleyici yoktur;
güncelleme Homebrew üzerinden kullanıcının komutuyla yapılır.

Resmî kaynaklar: [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook),
[Tap rehberi](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap),
[Apple Developer ID](https://developer.apple.com/developer-id/).
