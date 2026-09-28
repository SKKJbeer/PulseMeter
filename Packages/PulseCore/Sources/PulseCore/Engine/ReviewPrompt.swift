import Foundation

/// Wann die App um eine Bewertung im App Store bittet: einmal, nach der dritten
/// selbst gesicherten Ablesung.
///
/// **Warum die dritte.** Nach der ersten weiß niemand, ob die App etwas taugt;
/// eine Bewertung wäre geraten. Nach der zweiten steht der erste Verbrauch da.
/// Nach der dritten ist die App einmal wiederbenutzt worden, und genau dann
/// kann jemand sagen, ob sie hält, was sie verspricht. Später zu fragen hieße,
/// die meisten nie zu fragen: Wer nach vier Wochen noch abliest, ist eine
/// Minderheit, und deren Urteil fehlt dann in der Mitte.
///
/// **Warum nur einmal.** iOS zeigt die Frage höchstens dreimal im Jahr und
/// entscheidet selbst, ob überhaupt. Wer sie weggedrückt hat, soll sie von uns
/// nicht wieder bekommen, nur weil er weiter abliest.
///
/// **Was zählt.** Nur Ablesungen, die jemand im Ziffernblock gesichert hat.
/// Beispieldaten, ein Zählerwechsel und das Ändern einer alten Ablesung zählen
/// nicht; sie sagen nichts darüber, ob jemand die App wiederbenutzt.
public enum ReviewPrompt {

    public static let threshold = 3

    public static func shouldAsk(savedReadings: Int, alreadyAsked: Bool) -> Bool {
        !alreadyAsked && savedReadings >= threshold
    }
}
