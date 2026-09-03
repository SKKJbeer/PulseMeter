import SwiftUI
import PulseCore
import PulseUI

/// „Wie diese Zahl entsteht" — die Herleitung der Abschlagsvorschau.
///
/// **Warum es diesen Schirm gibt.** Auf der Übersichtskarte steht „≈ 288,12 €
/// Guthaben". Das ist die folgenreichste Zahl der App: Wer ihr glaubt, ändert
/// seinen Abschlag. Ohne Weg dahinter ist sie eine Sackgasse
/// (Produktprinzip 4), und der Entwurf konnte das seit Langem besser als die
/// App — eine Abweichung zwischen beiden ist ein Fehler und kein Zustand
/// (Regel 2). Vom Gründer am 3. September gefunden, indem er im Klick-Dummy
/// darauf getippt hat und in der App nicht weiterkam.
///
/// **Jeder Posten, der in die Summe eingeht, steht hier.** Der Entwurf hatte
/// genau hier seinen eigenen Fehler: Bei einem Photovoltaik-Zähler standen
/// 947,68 € und 154,80 € über einer Summe von 911,88 €, und die fehlenden
/// 190,60 € — die Einspeisevergütung — nannte er nirgends. Deshalb kommt die
/// Aufschlüsselung aus ``ForecastEngine/PrepaymentOutlook/Breakdown``, wo ein
/// Test zusichert, dass die Posten die Summe ergeben. Ein Schirm, der erklärt,
/// wie eine Zahl entsteht, und dabei einen Schritt auslässt, ist schlimmer als
/// keiner: Er sieht aus wie eine Herleitung.
struct ExplainView: View {
    let name: String
    let outlook: ForecastEngine.PrepaymentOutlook
    let unit: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    zeile("Verbrauch bis heute",
                          wert: menge(outlook.breakdown.consumptionToDate))
                    zeile("Hochrechnung aufs Jahr",
                          unterzeile: outlook.method.explanation,
                          wert: menge(outlook.breakdown.projectedConsumption))
                    zeile("Arbeitspreis", wert: betrag(outlook.breakdown.workingCost))
                    zeile("Grundpreis", wert: betrag(outlook.breakdown.standingCost))
                    if let gutschrift = outlook.breakdown.feedInCredit {
                        // Mit Minuszeichen, wie auf einer Rechnung — und in der
                        // Farbe, die in dieser App überall „zu deinen Gunsten"
                        // heißt.
                        zeile("Einspeisevergütung",
                              wert: "− " + betrag(gutschrift),
                              farbe: PulseColor.favourable)
                    }
                    zeile("Erwartete Kosten", wert: betrag(outlook.projectedCost),
                          summe: true)
                    zeile("Abschläge", wert: betrag(outlook.totalPrepayment))
                    zeile(outlook.expectsRefund
                          ? "Voraussichtliches Guthaben"
                          : "Voraussichtliche Nachzahlung",
                          wert: betrag(Money(abs(outlook.balance.amount),
                                             outlook.balance.currency)),
                          farbe: outlook.expectsRefund
                              ? PulseColor.favourable : PulseColor.adverse,
                          summe: true)

                    // **Der Satz bleibt stehen, auch wenn oben alles aufgeht.**
                    // Eine Herleitung macht eine Hochrechnung nicht zu einer
                    // Messung (Produktprinzip 7).
                    Text("""
                         Eine Hochrechnung ist nie eine gemessene Zahl. Sie wird \
                         genauer, je aktueller dein letzter Stand ist — und sie \
                         ersetzt die Abrechnung deines Versorgers nicht.
                         """)
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .background(PulseColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 18)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(PulseColor.ground)
            .navigationTitle("Wie diese Zahl entsteht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("erklaerung-\(name)")
    }

    /// Eine Zeile der Rechnung: Bezeichnung links, Wert rechts.
    ///
    /// Beide gehören zusammen — getrennt vorgelesen stünde „154,80 €" ohne
    /// seinen Posten da, und das ist die wiederkehrende Fehlerklasse dieses
    /// Projekts, nur mit den Ohren statt mit den Augen.
    private func zeile(_ titel: String, unterzeile: String? = nil,
                       wert: String, farbe: Color = PulseColor.ink,
                       summe: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel)
                        .font(summe ? .system(.body, weight: .semibold) : .body)
                        .foregroundStyle(PulseColor.ink)
                    if let unterzeile {
                        Text(unterzeile)
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Text(wert)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(farbe)
                    .monospacedDigit()
            }
            .padding(.vertical, 11)
            .accessibilityElement(children: .combine)
            Divider().overlay(summe ? PulseColor.ink : PulseColor.hairline)
        }
    }

    private func betrag(_ money: Money) -> String {
        money.amount.formatted(.currency(code: money.currency.code)
            .locale(Locale(identifier: "de_DE")))
    }

    private func menge(_ quantity: Quantity) -> String {
        let zahl = quantity.value.formatted(.number.precision(.fractionLength(0))
            .locale(Locale(identifier: "de_DE")))
        return "\(zahl) \(quantity.unit.symbol)"
    }
}
