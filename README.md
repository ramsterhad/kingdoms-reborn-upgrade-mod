# Kingdoms Reborn: Upgrade-Übersicht (Mod)

Zeigt im Statistik-Fenster (Tab **Buildings**) eine Übersicht aller Gebäude,
die du bereits einmal angeklickt hast: welche Upgrades es gibt, was schon
gekauft ist und was noch fehlt. Von dort aus lässt sich auch direkt upgraden
und zwischen den Gebäuden springen, ohne jedes einzeln im Spiel anzuklicken.

## Installation

### Zuerst: den richtigen Ordner öffnen

Du brauchst ihn für beide Varianten, und Steam findet ihn selbst:

1. In Steam in der **Bibliothek** mit der **rechten Maustaste** auf
   *Kingdoms Reborn* klicken
2. **Verwalten → Lokale Dateien durchsuchen**
3. Im geöffneten Fenster weiter in `PunCity` → `Binaries` → `Win64`

Das ist der **Zielordner**. Er bleibt für den Rest der Anleitung offen.
Du erkennst ihn daran, dass darin `PrototypeCity-Win64-Shipping.exe` liegt.

### Variante A: Ich weiß nicht, ob UE4SS installiert ist

Auch richtig, wenn du keine anderen Mods spielst. Schadet nie: ist UE4SS
schon da, wird es nur durch dieselbe Version ersetzt.

→ **`kingdoms-reborn-upgrade-mod-mit-UE4SS.zip`** von der
[Releases-Seite](../../releases/latest) laden.

1. ZIP entpacken (Rechtsklick → *Alle extrahieren*)
2. **Alles** aus dem entpackten Ordner in den Zielordner kopieren
3. Windows fragt nach → **„Dateien im Ziel ersetzen"** und
   **„Ordner zusammenführen"** wählen. Nichts vorher löschen.
4. Spiel starten

### Variante B: UE4SS ist schon installiert

→ Oben auf dieser Seite **Code → Download ZIP**.

1. ZIP entpacken
2. Aus der ZIP den Ordner `Mods\KRBuildingUpgrades` in den Ordner `Mods`
   im Zielordner kopieren
3. Im Zielordner `Mods\mods.txt` mit dem Editor öffnen (**nicht** die aus
   der ZIP) und diese Zeile ergänzen, falls sie fehlt:
   ```
   KRBuildingUpgrades : 1
   ```
4. Spiel starten

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
