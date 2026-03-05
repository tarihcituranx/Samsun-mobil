/// Uygulama genelinde kullanılan sabitler

// ─── TELEFERİK İSTASYONLARI (Doğru koordinatlar) ───
const double teleferikAltLat = 41.321695;
const double teleferikAltLon = 36.323563;
const double teleferikUstLat = 41.318939;
const double teleferikUstLon = 36.322455;

const String teleferikAltAd = 'Batıpark (Teleferik Alt İstasyon)';
const String teleferikUstAd = 'Amisos Tepesi (Teleferik Üst İstasyon)';

// ─── İLETİŞİM ───
const String samulasTelefon = '03624311012';
const String samulasTelefonGosterim = '0362 431 10 12';

// ─── AKTARMA KURALLARI ───
/// 1 saat içinde Otobüs↔Otobüs, Otobüs↔HRS, HRS↔Otobüs aktarması ücretsizdir.
const int aktarmaUcretsizSureDakika = 60;
/// 1 saat sonrasında yapılan aktarma ücreti (TL)
const double aktarmaSonrasiUcret = 8.0;

/// Aktarma kuralları açıklama metni
const String aktarmaKurallariMetni = '''AKTARMA KURALLARI

• 1 saat içinde yapılan aktarmalar:
  Otobüs → Otobüs, Otobüs → Hafif Raylı Sistem,
  Hafif Raylı Sistem → Otobüs aktarmaları ÜCRETSİZDİR.

• 1 saat sonrasında yapılan aktarmalar:
  8,00 TL ücretlendirilir.

• Düşük ücretli hattan yüksek ücretli hatta geçiş:
  Aradaki ücret farkı tahsil edilir.

• Aynı ücretli ya da daha düşük ücretli hatta geçiş:
  Ek ücret alınmaz.''';

/// İade kuralları açıklama metni
const String iadeKurallariMetni = '''İADE / ÜCRET DÜZELTME DURUMLARI

• 1 saat içindeki ücretsiz aktarmalarda ücret iadesi yapılmaz (zaten ücret alınmaz).
• Daha düşük ücretli hatta geçişlerde iade yapılmaz; sistem ek ücret tahsil etmez.
• Yüksek ücretli hatta geçişte fark ücreti alınır; iade söz konusu değildir.
• 1 saat sonrasında yapılan aktarmalarda tahsil edilen 8,00 TL iade edilmez.
• Abonman binişlerinde ücret iadesi uygulanmaz (biniş hakkı düşer).
• Kart kaybı durumunda kart bedeli iade edilmez.''';

// ─── OSRM YOL GEOMETRİSİ ───
/// Ücretsiz OSRM sunucusu — duraklar arası yol geometrisi çekmek için
const String osrmBaseUrl = 'https://router.project-osrm.org';
