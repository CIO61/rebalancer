# Rebalancer
Ezzel a bővítménnyel a játék egyensúlyának számos különféle eleme testre szabható.

## Használat
A bővítmény bemenetként mindössze egyetlen fájlt vár, amelynek a bővítményben meghatározott sémának megfelelő JSON-fájlnak kell lennie. A saját egyensúlyfájlok elkészítését megkönnyíti egy JSON-sémát támogató szövegszerkesztő használata.

## Épületelhelyezés és harci módok
Az egyensúlyfájl két szakasza egyedi értékeket módosít a játék kódjában:

* `building_placement`: a várépítési távolság az egyes térképméreteknél (milyen messze építhetők várelemek a vártornyodtól csetepatéban és többjátékos módban), valamint milyen közel lehetnek ellenséges egységek raktár, magtár vagy fegyvertár, ostromsátor, illetve MI-fal elhelyezésekor.
* `stances`: milyen messziről keresnek ellenséget a támadó és védekező harci módban lévő egységek, hányan indulnak ugyanazon ellenség ellen, valamint milyen messziről keresnek megtámadható épületet a támadó harci módú közelharci egységek.

Minden kulcs opcionális. A kihagyott kulcs megtartja a játék saját értékét, és a Rebalancer nem nyúl hozzá. Minden értéket a körülötte lévő kód alapján keres meg a Stronghold Crusader és a Crusader Extreme játékban, és csak akkor írja felül, ha még a játék eredeti értékét tartalmazza. Ha egy érték nem található, vagy egy másik modul már megváltoztatta, az adott beállítás kimarad, és a napló rögzíti az okát. A séma minden kulcsot felsorol a megengedett tartományával és a játék eredeti értékével együtt.
