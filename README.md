# Kingdoms Reborn: Upgrade-Übersicht (Mod)

Zeigt im Statistik-Fenster (Tab **Buildings**) eine Übersicht aller Gebäude,
die du bereits einmal angeklickt hast: welche Upgrades es gibt, was schon
gekauft ist und was noch fehlt. Von dort aus lässt sich auch direkt upgraden
und zwischen den Gebäuden springen, ohne jedes einzeln im Spiel anzuklicken.

## Installation

Es gibt zwei ZIP-Dateien. Lies zuerst, welche du brauchst.

### Ich weiß nicht, ob UE4SS installiert ist / spiele keine anderen Mods

→ Lade **`kingdoms-reborn-upgrade-mod-mit-UE4SS.zip`** von der
[Releases-Seite](../../releases/latest) herunter.

1. ZIP entpacken.
2. **Allen** Inhalt des entpackten Ordners kopieren nach:
   `...\Kingdoms Reborn\PunCity\Binaries\Win64\`
   (Ordner mit gleichem Namen zusammenführen, nichts löschen, mit „Ersetzen"
   bestätigen falls gefragt.)
3. Spiel starten.

### UE4SS ist bei mir schon installiert (ich spiele schon andere Mods)

→ Oben auf dieser Seite auf **Code → Download ZIP** klicken.

1. ZIP entpacken.
2. Den Ordner `Mods\KRBuildingUpgrades` aus der ZIP kopieren nach:
   `...\Kingdoms Reborn\PunCity\Binaries\Win64\Mods\`
3. Die Datei `Mods\mods.txt` (im selben `Win64`-Ordner, **nicht** die aus der
   ZIP) mit einem Texteditor öffnen und diese Zeile ergänzen, falls sie fehlt:
   ```
   KRBuildingUpgrades : 1
   ```
4. Spiel starten.

**Im Zweifel** die erste Variante (mit UE4SS) nehmen: schadet nicht, auch
wenn UE4SS schon da ist, überschreibt nur mit derselben Version.

## Bedienung

Die Übersicht erscheint im Statistik-Fenster, Tab **Buildings**. Sie startet
zugeklappt, damit die Gebäudetabelle darunter frei bleibt.

- **Kopfzeile** anklicken klappt die Liste auf und zu. Der Zustand bleibt
  über Spielneustarts erhalten.
- **`collect all information`** liest alle Gebäude einmal durch. Der Balken
  zählt dabei mit; ein zweiter Klick bricht ab. **Die Kamera wandert dabei
  durch die Stadt** — das ist normal, es ist der einzige Weg, ein Gebäude
  auszulesen.
- **Typzeile** (z. B. `> Beekeeper`) liest alle Gebäude dieses Typs ein.
  Kürzer als `collect all information`, wenn nur ein Typ interessiert.
- **Gebäudezeile** (z. B. `Beekeeper #2`) liest genau dieses eine Gebäude
  ein. Gedimmt heißt: dort ist nichts mehr zu tun.
- **Upgradezeile** kauft das Upgrade. Ist das Gebäude gerade nicht
  ausgewählt, springt der erste Klick hin und der zweite kauft.

Farben in der Liste:

| Farbe | Bedeutung |
|-------|-----------|
| grün  | kaufbar, ein Klick genügt |
| rot   | zu teuer, nicht anklickbar |
| grau  | schon gekauft |

Ohne `collect all information` zeigt die Liste pro Gebäudetyp nur das zuletzt
angeklickte Gebäude, erkennbar an `(last seen)`. Das ist Absicht: Upgrades
gehören zum einzelnen Gebäude, nicht zum Typ — zwei Imkereien können
unterschiedlich weit ausgebaut sein.

## Bei Problemen

Sag kurz Bescheid, am besten mit einem Screenshot.
