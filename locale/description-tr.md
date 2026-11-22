# Rebalancer
Bu uzantı, oyun dengesinin çok çeşitli yönlerini yapılandırmak için kullanılabilir.

## Kullanım
Uzantı girdi olarak yalnızca tek bir dosya alır; bu dosyanın uzantı içinde tanımlanan şemaya uyan bir JSON dosyası olması beklenir. JSON şeması desteğine sahip bir metin düzenleyici kullanmak kendi denge dosyalarınızı oluşturmanıza yardımcı olabilir.

## Bina yerleştirme ve duruşlar
Denge dosyasının iki bölümü oyun kodundaki tekil değerleri değiştirir:

* `building_placement`: her harita boyutu için kale inşa menzili (çarpışma ve çok oyunculu modda kale parçalarının iç kalenizden ne kadar uzağa inşa edilebileceği) ve bir depo, ambar veya cephanelik, bir kuşatma çadırı ya da bir yapay zekâ suru yerleştirilirken düşman birimlerinin ne kadar yakında olabileceği.
* `stances`: saldırgan ve savunma duruşundaki birimlerin düşmanları ne kadar uzaktan aradığı, kaç tanesinin aynı düşmana yöneldiği ve saldırgan yakın dövüş birimlerinin saldırmak için bir binayı ne kadar uzaktan aradığı.

Her anahtar isteğe bağlıdır. Belirtilmeyen bir anahtar oyunun kendi değerini korur ve Rebalancer buna dokunmaz. Her değer, Stronghold Crusader ve Crusader Extreme içinde çevresindeki koda göre bulunur ve yalnızca hâlâ oyunun kendi değerini taşıyorsa yazılır. Bir değer bulunamazsa veya başka bir modül onu zaten değiştirmişse ilgili ayar atlanır ve günlükte nedeni belirtilir. Şema, her anahtarı izin verilen aralığı ve oyunun kendi değeriyle birlikte listeler.
