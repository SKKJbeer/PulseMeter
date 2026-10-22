#!/usr/bin/env python3
"""Schreibt die Gewichte des Ziffernnetzes dorthin, wo sie gebraucht werden.

Quelle ist `scripts/kamera-netz/ziffernnetz.bin` (erzeugt von `export.py` nach dem
Training). Daraus entstehen:

  * `Packages/PulseCore/Sources/PulseCore/Camera/DigitNetWeights.swift`: die App
  * der Block `ZIFFERNNETZ` in `docs/prototype/index.html`: der Klick-Dummy

Warum als Quelltext statt als Ressource: Ein Swift-Paket mit Ressourcen braucht
`Bundle.module`, und ob das im App-Bau, im Widget und unter Linux gleich
ausfällt, hätte erst ein Mac-Lauf gezeigt. Eine Zeichenkette im Quelltext ist
überall dieselbe.

    scripts/kamera-gewichte.py            schreibt beide
    scripts/kamera-gewichte.py --pruefen  bricht ab, wenn eine Stelle von der Quelle abweicht
"""
import base64, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BIN = ROOT / "scripts/kamera-netz/ziffernnetz.bin"
SWIFT = ROOT / "Packages/PulseCore/Sources/PulseCore/Camera/DigitNetWeights.swift"
HTML = ROOT / "docs/prototype/index.html"

SWIFT_VORLAGE = """import Foundation

// ERZEUGT von scripts/kamera-gewichte.py aus scripts/kamera-netz/ziffernnetz.bin.
// Nicht von Hand ändern: `scripts/pruefen.sh` bricht ab, wenn die Datei von der
// Quelle abweicht.
extension DigitNet {

    /// Das trainierte Netz, wie es in der App läuft.
    public static let bundled: DigitNet = {
        guard let data = Data(base64Encoded: weightsBase64, options: .ignoreUnknownCharacters),
              let net = try? DigitNet(weights: data) else {
            preconditionFailure("Die eingebauten Gewichte des Ziffernnetzes sind unlesbar")
        }
        return net
    }()

    private static let weightsBase64 = \"\"\"
@@KOERPER@@
        \"\"\"
}
"""

def swift_text(b64: str) -> str:
    lines = [b64[i:i + 100] for i in range(0, len(b64), 100)]
    return SWIFT_VORLAGE.replace("@@KOERPER@@", "\n".join("        " + l for l in lines))

def html_block(b64: str) -> str:
    return f"/* ZIFFERNNETZ:start (erzeugt von scripts/kamera-gewichte.py, nicht von Hand ändern) */\nconst ZIFFERNNETZ_B64 = \"{b64}\";\n/* ZIFFERNNETZ:end */"

def main():
    b64 = base64.b64encode(BIN.read_bytes()).decode()
    want_swift = swift_text(b64)
    html = HTML.read_text(encoding="utf-8") if HTML.exists() else ""
    has_block = "/* ZIFFERNNETZ:start" in html
    pat = re.compile(r"/\* ZIFFERNNETZ:start.*?/\* ZIFFERNNETZ:end \*/", re.S)
    want_html = pat.sub(lambda m: html_block(b64), html) if has_block else html
    if "--pruefen" in sys.argv:
        bad = []
        if not SWIFT.exists() or SWIFT.read_text(encoding="utf-8") != want_swift: bad.append(str(SWIFT.relative_to(ROOT)))
        if has_block and html != want_html: bad.append("docs/prototype/index.html (Block ZIFFERNNETZ)")
        if bad:
            print("✗ Gewichte des Ziffernnetzes weichen von der Quelle ab: " + ", ".join(bad)
                  + "\n  scripts/kamera-gewichte.py ausführen.")
            sys.exit(1)
        print("Gewichte des Ziffernnetzes: Swift und Klick-Dummy stimmen mit der Quelle überein.")
        return
    SWIFT.write_text(want_swift, encoding="utf-8")
    if has_block: HTML.write_text(want_html, encoding="utf-8")
    print(f"{len(BIN.read_bytes())} Bytes → {SWIFT.relative_to(ROOT)}" + (" und Klick-Dummy" if has_block else ""))

main()
