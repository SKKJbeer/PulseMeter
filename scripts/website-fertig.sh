#!/usr/bin/env bash
# Legt die auslieferbare Website in einen Ordner — genau das, was ins Netz geht.
#
# **Warum das nicht `docs/website/` selbst ist.** Dort liegen zwei Dateien, die
# niemanden außer dem Gründer etwas angehen: `EINTRAGEN.md` mit seiner
# Anschrift und den offenen Stellen, und `CLOUDFLARE.md` mit der Einrichtung.
# Der Zweigweg hat sie entfernt, der Upload über wrangler hätte sie
# mitgeschickt — zwei Wege, die dasselbe tun sollen und es nicht taten.
# Genau die Fehlerklasse, die dieses Projekt schon zweimal bezahlt hat.
#
# Also: **ein** Ort, an dem entschieden wird, was ausgeliefert wird.
#
#   scripts/website-fertig.sh build/website
set -euo pipefail
cd "$(dirname "$0")/.."

ZIEL="${1:?Aufruf: scripts/website-fertig.sh <zielordner>}"
QUELLE="docs/website"

rm -rf "$ZIEL"
mkdir -p "$ZIEL"
cp -R "$QUELLE"/. "$ZIEL"/

# Was im Repository bleibt und nicht ins Netz geht.
rm -f "$ZIEL"/EINTRAGEN.md "$ZIEL"/CLOUDFLARE.md

# **Kein Verzeichnis auflisten.** Ohne diese Datei liefert Pages `/bilder/` als
# Liste aus, und die Dateiablage stünde offen im Netz.
#
# **Bilder und Symbole dürfen eine Woche im Browser bleiben.** Bis 0.117.0
# kam alles mit `max-age=0`: Jeder Aufruf lud die zehn Telefonbilder der
# Startseite neu, rund 600 KB, und Googles Messung der Ladezeit zählt genau
# das. Die Seiten selbst bleiben bei `max-age=0`, damit eine Änderung sofort
# ankommt. Das Stylesheet eine Stunde: Sein Name trägt keine Fassung, und
# eine Woche alter Stil zu neuem Text sähe kaputt aus.
cat > "$ZIEL/_headers" <<'ENDE'
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: SAMEORIGIN

/bilder/*
  Cache-Control: public, max-age=604800, stale-while-revalidate=86400

/favicon.ico
  Cache-Control: public, max-age=604800

/favicon.svg
  Cache-Control: public, max-age=604800

/apple-touch-icon.png
  Cache-Control: public, max-age=604800

/stil.css
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
ENDE

# **Adressen ohne `.html`.** Cloudflare Pages liefert `/datenschutz.html` nicht
# aus, sondern leitet mit 308 auf `/datenschutz` weiter. Gemessen, nicht
# vermutet — der erste Aufruf der fertigen Seite hat es gezeigt. Damit zeigte
# jedes `canonical` auf eine Adresse, die weiterleitet, und die Sitemap meldete
# fünf Adressen an, die es so nicht gibt. Google hält `canonical` für die
# Wahrheit; ein Widerspruch dort kostet Sichtbarkeit.
#
# Umgeschrieben wird **nur im Auslieferordner**. Im Repository bleiben die
# `.html`, sonst ließe sich die Seite lokal nicht mehr durchklicken und die
# Prüfung fände ihre Verweise nicht mehr.
python3 - "$ZIEL" <<'ENDE_PY'
import pathlib, re, sys

ordner = pathlib.Path(sys.argv[1])
namen = [p.stem for p in ordner.glob("*.html")]

def adresse(treffer):
    name = treffer.group(1)
    return "/" if name == "index" else f"/{name}"

for datei in list(ordner.glob("*.html")) + [ordner / "sitemap.xml"]:
    if not datei.exists():
        continue
    text = datei.read_text(encoding="utf-8")
    # Verweise zwischen den Seiten: href="hilfe.html" → href="/hilfe", und
    # mit Sprungmarke: href="index.html#preise" → href="/#preise".
    #
    # **Die Sprungmarke fehlte bis 0.117.0.** Solange jede Seite im
    # Wurzelverzeichnis lag, fiel das nicht auf: `index.html#preise` leitete
    # Cloudflare auf `/#preise` weiter. Die Seite für unbekannte Adressen
    # antwortet aber auch unter `/ratgeber/xyz`, und dort zeigt derselbe
    # Verweis auf `/ratgeber/index.html`, also wieder ins Leere.
    text = re.sub(r'href="([a-z0-9-]+)\.html(#[^"]*)?"',
                  lambda m: f'href="{adresse(m)}{m.group(2) or ""}"' if m.group(1) in namen else m.group(0),
                  text)
    # Absolute Adressen in canonical, og:url und Sitemap
    text = re.sub(r'(https://[^"<\s]+/)([a-z0-9-]+)\.html',
                  lambda m: m.group(1) + ("" if m.group(2) == "index" else m.group(2)),
                  text)
    datei.write_text(text, encoding="utf-8")

# Nachzählen statt hoffen: Bleibt ein `.html`-Verweis stehen, war die Regel zu eng.
rest = []
for datei in ordner.glob("*.html"):
    for treffer in re.findall(r'href="[^"]*\.html(?:#[^"]*)?"', datei.read_text(encoding="utf-8")):
        rest.append(f"{datei.name}: {treffer}")
if rest:
    sys.exit("Verweise mit .html sind stehengeblieben:\n  " + "\n  ".join(rest))
ENDE_PY

# **Der Laden-Knopf sagt dem App Store, dass er von hier kommt.** Mit `pt`
# (der Anbieterkennung aus App Store Connect) und `ct` (einem Kennwort je
# Seite) zeigt App Store Connect unter „Kampagnen", wie viele über die Website
# auf die Store-Seite kamen und wie viele geladen haben. Die Kennung ist nicht
# geheim, sie steht in jedem Kampagnen-Link. Solange sie fehlt, bleibt der
# Knopf, wie er ist: Ein `ct` ohne `pt` wertet Apple nicht aus.
APPSTORE_PT="${APPSTORE_PT:-}"
if [ -n "$APPSTORE_PT" ]; then
  python3 - "$ZIEL" "$APPSTORE_PT" <<'ENDE_PY'
import pathlib, re, sys
ordner, pt = pathlib.Path(sys.argv[1]), sys.argv[2]
if not re.fullmatch(r"[0-9]{4,12}", pt):
    sys.exit(f"APPSTORE_PT sieht nicht aus wie eine Anbieterkennung: {pt!r}")
laden = 'href="https://apps.apple.com/de/app/id6802262743"'
for datei in ordner.glob("*.html"):
    text = datei.read_text(encoding="utf-8")
    if laden in text:
        kennwort = "website-" + ("start" if datei.stem == "index" else datei.stem)
        text = text.replace(laden, f'href="https://apps.apple.com/de/app/id6802262743?pt={pt}&amp;ct={kennwort}&amp;mt=8"')
        datei.write_text(text, encoding="utf-8")
        print(f"Kampagne {kennwort} in {datei.name}")
ENDE_PY
fi

# Fällt jemandem eine weitere Datei ein, die nicht ins Netz gehört, gehört sie
# hierher — und die Prüfung darunter merkt es, wenn sie es doch tut.
if find "$ZIEL" -name "*.md" | grep -q .; then
  echo "Im Auslieferordner liegt noch eine Markdown-Datei:" >&2
  find "$ZIEL" -name "*.md" >&2
  exit 1
fi

echo "$(find "$ZIEL" -type f | wc -l | tr -d ' ') Dateien in $ZIEL"
