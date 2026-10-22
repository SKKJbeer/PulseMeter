import Foundation

/// Ein gezeichnetes Siebensegment-Bild: für Prüfungen und für die Vorführung ohne
/// Kamera.
///
/// Im Simulator gibt es keine Kamera, und trotzdem soll der ganze Weg getestet
/// werden: Bild → Rahmen → Netz → Leser → Ziffernblock. Dieses Bild geht durch
/// genau dieselbe Auswertung wie ein Kamerabild. Es ist absichtlich schlicht
/// (dunkle Balken auf hellem Grund, eine Schrift); ob das Netz auch mit echten
/// Anzeigen zurechtkommt, zeigen die Fotos in `docs/kamera/`.
public enum DemoFrame {

    /// 240 × 48, wie der Eingang des Netzes. Erlaubt sind Ziffern und Punkt.
    public static func render(_ text: String) -> GrayImage {
        let w = DigitNet.inputWidth, h = DigitNet.inputHeight, ss = 4
        var canvas = [Bool](repeating: false, count: w * ss * h * ss)
        let digitHeight = 30.0, digitWidth = 16.0, stroke = 4.0, gap = 1.0, space = 7.0
        let digits = text.filter { $0.isNumber }.count
        let dots = text.filter { $0 == "." }.count
        let total = Double(digits) * (digitWidth + space) + Double(dots) * 3
        var x = (Double(w) - total) / 2
        let y0 = (Double(h) - digitHeight) / 2

        func fill(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) {
            let a = max(0, Int((x0 * Double(ss)).rounded())), b = min(w * ss, Int((x1 * Double(ss)).rounded()))
            let c = max(0, Int((y0 * Double(ss)).rounded())), d = min(h * ss, Int((y1 * Double(ss)).rounded()))
            guard a < b, c < d else { return }
            for yy in c..<d { for xx in a..<b { canvas[yy * w * ss + xx] = true } }
        }

        // a b c d e f g
        let segments: [Character: String] = [
            "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
            "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"]
        for ch in text {
            if ch == "." {
                fill(x - space / 2 - 1, y0 + digitHeight - stroke, x - space / 2 + 2, y0 + digitHeight)
                x += 3
                continue
            }
            guard let on = segments[ch] else { continue }
            let half = digitHeight / 2
            for s in on {
                switch s {
                case "a": fill(x + gap, y0, x + digitWidth - gap, y0 + stroke)
                case "g": fill(x + gap, y0 + half - stroke / 2, x + digitWidth - gap, y0 + half + stroke / 2)
                case "d": fill(x + gap, y0 + digitHeight - stroke, x + digitWidth - gap, y0 + digitHeight)
                case "b": fill(x + digitWidth - stroke, y0 + gap, x + digitWidth, y0 + half - gap)
                case "c": fill(x + digitWidth - stroke, y0 + half + gap, x + digitWidth, y0 + digitHeight - gap)
                case "f": fill(x, y0 + gap, x + stroke, y0 + half - gap)
                case "e": fill(x, y0 + half + gap, x + stroke, y0 + digitHeight - gap)
                default: break
                }
            }
            x += digitWidth + space
        }

        var pixels = [UInt8](repeating: 0, count: w * h)
        for yy in 0..<h {
            for xx in 0..<w {
                var ink = 0
                for sy in 0..<ss { for sx in 0..<ss where canvas[(yy * ss + sy) * w * ss + xx * ss + sx] { ink += 1 } }
                let share = Double(ink) / Double(ss * ss)
                pixels[yy * w + xx] = UInt8((205 - 165 * share).rounded())
            }
        }
        return GrayImage(width: w, height: h, pixels: pixels)
    }
}
