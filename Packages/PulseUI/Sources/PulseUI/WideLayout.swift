import SwiftUI

/// Wann aus einer Spalte zwei werden — und wie breit die zweite ist.
///
/// **Das Problem, das dahintersteckt.** `Verlauf` und `Zähler` waren bis 1.1
/// eine einzige Spalte aus Karten, quer über die ganze Fensterbreite. Auf dem
/// Telefon ist das richtig. Auf einem 13-Zoll-Schirm im Querformat sind es
/// über tausend Punkte Breite: Eine Zeile „Alle Ablesungen · 14 Einträge" steht
/// dann links, ihr Pfeil tausend Punkte weiter rechts, und dazwischen ist
/// nichts. Der Inhalt endet im oberen Drittel, darunter bleibt der halbe
/// Bildschirm leer.
///
/// **Die Antwort ist eine Bühne und eine Leiste.** Links das eine, wofür der
/// Schirm da ist — das Diagramm, die Tabelle, die Liste der Zähler. Rechts in
/// fester Breite alles, was es begleitet: Vergleich, Ausfuhr, Bericht,
/// Erinnerungen, Archiv. Zwei Dinge auf einmal, beide in einer Breite, in der
/// sie sich lesen lassen.
///
/// **Warum die Leiste eine feste Breite hat und keinen Anteil.** Ihr Inhalt
/// sind Zeilen aus einem Wort und einem Pfeil. Die haben eine natürliche
/// Breite von etwa dreieinhalb hundert Punkten; ein Anteil würde sie auf einem
/// größeren Schirm mitwachsen lassen und genau den Fehler wiederholen, gegen
/// den die Aufteilung antritt.
///
/// **Warum nicht an der Größenklasse entschieden wird.** `.regular` heißt nur
/// „nicht Telefon". Ein iPad im Hochformat gibt der Detailspalte rund 710
/// Punkte; nach Abzug der Leiste bliebe eine Bühne von 334, und ein Diagramm
/// in 334 Punkten ist schlechter als eines in 710. Entschieden wird deshalb an
/// der Breite, die wirklich da ist.
public enum WideLayout {

    /// Die Leiste rechts.
    public static let railWidth: CGFloat = 360

    /// Der Abstand zwischen Bühne und Leiste.
    public static let gutter: CGFloat = 18

    /// Was der Bühne mindestens bleiben muss, damit die Teilung sich lohnt.
    ///
    /// 440 Punkte sind ungefähr ein iPhone im Querformat — darunter wird ein
    /// Diagramm mit zwölf Balken zum Kamm.
    public static let minimumStage: CGFloat = 440

    /// Ob sich bei dieser Breite zwei Spalten lohnen.
    public static func splits(_ width: CGFloat) -> Bool {
        width - railWidth - gutter >= minimumStage
    }

    /// Ob das Fenster so breit ist, dass eine Ansicht sich Luft nehmen darf —
    /// höhere Diagramme, mehr Rand —, auch wenn sie einspaltig bleibt.
    ///
    /// Das ist der Fall des iPads im Hochformat: zu schmal für zwei Spalten,
    /// zu breit für die Maße des Telefons.
    public static func roomy(_ width: CGFloat) -> Bool { width >= 640 }

    /// Der seitliche Rand. Auf dem Telefon knapp, auf einem großen Schirm
    /// etwas mehr — ein Text, der die Fensterkante berührt, sieht auf einem
    /// Tablet nach Versehen aus.
    public static func margin(_ width: CGFloat) -> CGFloat {
        roomy(width) ? 24 : 18
    }

    /// Was der Bühne nach Rändern und Leiste wirklich bleibt.
    public static func stageWidth(_ width: CGFloat) -> CGFloat {
        let inhalt = width - 2 * margin(width)
        return splits(width) ? inhalt - railWidth - gutter : inhalt
    }

    /// Wie breit ein Umschalter über den Spalten sein darf.
    ///
    /// **Ein Segmentwähler mit zwei Feldern über 1300 Punkte ist keine Wahl
    /// mehr, sondern eine Wand.** Gekappt wird auf die Breite der Bühne, nicht
    /// auf ein rundes Maß: Dann steht der Umschalter genau über dem, was er
    /// umschaltet, und die Kante stimmt mit der des Diagramms überein.
    public static func controlWidth(_ width: CGFloat) -> CGFloat? {
        splits(width) ? stageWidth(width) : nil
    }

    /// Wie hoch die Balken eines Diagramms stehen.
    ///
    /// Die 140 vom Telefon sind kein Maß, sondern ein Rest: Sie stammen aus
    /// einem Schirm, auf dem darunter noch vier Karten hermussten. Breiter
    /// wurde das Bild bisher trotzdem — die Balken zogen in die Breite und
    /// blieben flach, und auf einem Tablet sah das Diagramm dadurch gedrückt
    /// aus.
    ///
    /// **Das Verhältnis ist nicht erfunden, sondern abgelesen.** Im
    /// Klick-Dummy ist dasselbe Diagramm ein SVG mit dem Ansichtsfeld
    /// 322 × 148; es wächst dort seit jeher mit der Breite. Hier steht
    /// dasselbe Verhältnis, damit Entwurf und App nicht auseinanderlaufen
    /// (Regel 2).
    ///
    /// Gerechnet wird mit der Breite der **Bühne**, nicht des Fensters: In
    /// zwei Spalten steht das Diagramm in der linken, und die ist um die
    /// Leiste schmaler.
    public static func chartHeight(_ width: CGFloat) -> CGFloat {
        let buehne = stageWidth(width)
        // Unterhalb eines Tablets bleibt alles, wie es war. Das Telefon ist
        // der Schirm, für den die 140 einmal entschieden wurden, und dort
        // stehen unter dem Diagramm weiter vier Karten.
        guard buehne > 420 else { return 140 }
        // Nach oben ein Deckel: Ein Fenster in Stage Manager kann sehr breit
        // werden, und ein Diagramm, das nicht mehr auf den Schirm passt,
        // verlangt zum Ablesen genau das Blättern, das die Aufteilung
        // abschaffen sollte.
        return Swift.min(320, buehne * 148 / 322)
    }
}
