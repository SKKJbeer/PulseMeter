#!/usr/bin/env python3
"""Schreibt die Gewichte des Ziffernnetzes dorthin, wo sie gebraucht werden.

Quelle ist `scripts/kamera-netz/ziffernnetz.bin` (erzeugt von `export.py` nach dem
Training; mehrere Netze: `ziffernnetz-1.bin`, `ziffernnetz-2.bin`, …). Daraus entstehen:

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
BINS = sorted((ROOT / "scripts/kamera-netz").glob("ziffernnetz-*.bin"))
SWIFT = ROOT / "Packages/PulseCore/Sources/PulseCore/Camera/DigitNetWeights.swift"
HTML = ROOT / "docs/prototype/index.html"

SWIFT_VORLAGE = """import Foundation

// ERZEUGT von scripts/kamera-gewichte.py aus scripts/kamera-netz/ziffernnetz-*.bin.
// Nicht von Hand ändern: `scripts/pruefen.sh` bricht ab, wenn die Datei von der
// Quelle abweicht.
extension DigitNet {

    /// Die trainierten Netze, wie sie in der App laufen. Eine Zeile gilt nur, wenn alle denselben
    /// Text lesen (``DigitEnsemble``).
    public static let bundledNets: [DigitNet] = weightsBase64.map { text in
        guard let data = Data(base64Encoded: text, options: .ignoreUnknownCharacters),
              let net = try? DigitNet(weights: data) else {
            preconditionFailure("Die eingebauten Gewichte des Ziffernnetzes sind unlesbar")
        }
        return net
    }

    private static let weightsBase64: [String] = [
@@KOERPER@@
    ]
}
"""

def swift_text(b64s: list[str]) -> str:
    teile = []
    for b64 in b64s:
        lines = [b64[i:i + 100] for i in range(0, len(b64), 100)]
        teile.append('        """\n' + "\n".join("        " + l for l in lines) + '\n        """')
    return SWIFT_VORLAGE.replace("@@KOERPER@@", ",\n".join(teile))

def html_block(b64s: list[str]) -> str:
    liste = ",\n  ".join(f'"{b}"' for b in b64s)
    return f"/* ZIFFERNNETZ:start (erzeugt von scripts/kamera-gewichte.py, nicht von Hand ändern) */\nconst ZIFFERNNETZ_B64 = [\n  {liste}\n];\n/* ZIFFERNNETZ:end */"

def main():
    b64 = [base64.b64encode(p.read_bytes()).decode() for p in BINS]
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
    print(f"{len(BINS)} Netze → {SWIFT.relative_to(ROOT)}" + (" und Klick-Dummy" if has_block else ""))

main()
