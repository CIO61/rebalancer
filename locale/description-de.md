# Rebalancer
Mit dieser Erweiterung lassen sich zahlreiche Aspekte der Spielbalance anpassen.

## Verwendung
Die Erweiterung nimmt lediglich eine Datei als Eingabe entgegen. Dabei muss es sich um eine JSON-Datei handeln, die dem Schema dieser Erweiterung entspricht. Ein Texteditor mit Unterstützung für JSON-Schemata erleichtert das Erstellen eigener Balance-Dateien.

## Gebäudeplatzierung und Haltungen
Zwei Abschnitte der Balance-Datei ändern einzelne Werte im Spielcode:

* `building_placement`: der Burgbau-Radius für jede Kartengröße (wie weit entfernt vom eigenen Bergfried Burgteile im Gefecht und Mehrspielermodus gebaut werden dürfen) sowie wie nahe gegnerische Einheiten beim Platzieren von Vorratslager, Kornspeicher oder Waffenkammer, eines Belagerungszelts oder einer KI-Mauer sein dürfen.
* `stances`: wie weit Einheiten in aggressiver und defensiver Haltung nach Gegnern suchen, wie viele von ihnen denselben Gegner verfolgen und wie weit aggressive Nahkampfeinheiten nach einem anzugreifenden Gebäude suchen.

Jeder Schlüssel ist optional. Ein weggelassener Schlüssel behält den Originalwert des Spiels, und Rebalancer fasst ihn nicht an. Jeder Wert wird anhand des umgebenden Codes in Stronghold Crusader und Crusader Extreme gefunden und nur dann überschrieben, wenn er noch den Originalwert des Spiels enthält. Lässt sich ein Wert nicht finden oder wurde er bereits von einem anderen Modul geändert, wird diese Einstellung übersprungen und der Grund im Protokoll vermerkt. Das Schema listet jeden Schlüssel mit seinem zulässigen Wertebereich und dem Originalwert des Spiels auf.
