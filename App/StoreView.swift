import SwiftUI
import PulseCore
import PulseUI

/// Alles, was sich freischalten lässt, an einer Stelle — und direkt kaufbar.
///
/// **Warum es das jetzt doch gibt.** In `UnlockSheet` steht seit 0.40.0 der
/// Satz „ein eigener Schirm mit allen Produkten wäre ein Ort, den niemand
/// aufsucht". Für **einen** Kauf war das richtig. Bei fünf ist es falsch
/// geworden: Die Kaufseite öffnet sich ausschließlich an einer Grenze, und wer
/// wissen will, was die App überhaupt kann, findet nirgends eine Antwort.
/// Vom Gründer benannt: „bei so vielen Möglichkeiten zum Kaufen benötigt es
/// einen Menüpunkt, dezent, wo man drauf kann und eine Übersicht bekommt."
///
/// **Der Unterschied zu `UnlockSheet`.** Dort steht eine Funktion, weil der
/// Nutzer gerade davorsteht — mit einem erklärenden Satz. Hier stehen alle,
/// weil er nachsieht, und dann zählen Stichpunkte: Was bekomme ich, was habe
/// ich schon, was kostet es. Kein Absatz, den man liest, sondern eine Liste,
/// die man überfliegt.
struct StoreView: View {

    @Environment(Purchase.self) private var purchase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Das Bündel steht **oben**, nicht unten: Wer die Übersicht
                    // aufsucht, sucht den Überblick, und der beginnt bei dem
                    // Kauf, der alles enthält. In `UnlockSheet` ist es
                    // umgekehrt — dort steht die eine Sperre oben, an der
                    // jemand gerade hängt.
                    if !purchase.allows(.everything) { bundleCard }

                    Text("Einzeln")
                        .pulseSectionLabel()
                    ForEach(ProductID.individually, id: \.self) { produkt in
                        card(for: produkt)
                    }

                    freeCard

                    if !purchase.gateway.isAvailable {
                        StatusBanner(
                            tone: .notice,
                            message: AttributedString("Der App Store liefert gerade keine Käufe aus. Die Preise sind deshalb Richtwerte.")
                        )
                        if let befund = purchase.gateway.storeDiagnosis {
                            Text(befund)
                                .font(PulseText.detail)
                                .foregroundStyle(PulseColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("store-befund")
                        }
                    }

                    if let problem = purchase.problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("Freischalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Wiederherstellen") {
                        Task { await purchase.restore() }
                    }
                    .font(PulseText.caption)
                }
            }
        }
    }

    // MARK: - Bausteine

    /// Ein Kauf: Name, Stichpunkte, Preis — oder ein Haken, wenn er schon da ist.
    private func card(for produkt: ProductID) -> some View {
        let gekauft = purchase.allows(produkt)
        return PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(produkt.title)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PulseColor.ink)
                    Spacer(minLength: 8)
                    if gekauft {
                        Label("Freigeschaltet", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(PulseText.caption)
                            .foregroundStyle(PulseColor.tint)
                    }
                }

                punkte(produkt.includes, erledigt: gekauft)

                if !gekauft {
                    kaufKnopf(produkt, prominent: false)
                }
            }
            .padding(15)
        }
        // **Eine Karte, ein Element.** Ohne das liest VoiceOver Titel,
        // Stichpunkte und Preis als sechs Einzelstücke vor, zwischen denen
        // niemand den Zusammenhang hört.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("kaufkarte-\(produkt.rawValue)")
    }

    /// Das Bündel, mit dem, was es ersetzt — und der ausgerechneten Ersparnis.
    private var bundleCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(ProductID.everything.title)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(PulseColor.ink)

                punkte(ProductID.everything.includes, erledigt: false)

                Text(ersparnis)
                    .font(PulseText.caption)
                    .foregroundStyle(PulseColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                kaufKnopf(.everything, prominent: true)
            }
            .padding(15)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("kaufkarte-everything")
    }

    /// Was nichts kostet. Steht unter den Preisen und nicht im Kleingedruckten.
    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dauerhaft kostenlos")
                .pulseSectionLabel()
            PulseCard {
                punkte(ProductID.alwaysFree, erledigt: true)
                    .padding(15)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("kostenlos-karte")
        }
    }

    /// Stichpunkte mit Haken davor — dieselbe Form für Gekauftes, Käufliches
    /// und Kostenloses, damit die Liste vergleichbar bleibt.
    private func punkte(_ zeilen: [String], erledigt: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(zeilen, id: \.self) { zeile in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: erledigt ? "checkmark" : "circle.fill")
                        .font(.system(size: erledigt ? 11 : 5, weight: .bold))
                        .foregroundStyle(erledigt ? PulseColor.tint : PulseColor.inkTertiary)
                        .frame(width: 12)
                    Text(zeile)
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func kaufKnopf(_ produkt: ProductID, prominent: Bool) -> some View {
        Button {
            Task { await purchase.buy(produkt) }
        } label: {
            HStack {
                Text("Freischalten")
                    .font(.system(.body, weight: .semibold))
                Spacer(minLength: 8)
                Text(purchase.price(for: produkt))
                    .font(.system(.body, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(prominent ? PulseColor.onAccent : PulseColor.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(prominent ? PulseColor.tint : PulseColor.surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(prominent ? .clear : PulseColor.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchase.isWorking || !purchase.gateway.isAvailable)
        .accessibilityLabel("\(produkt.title) freischalten für \(purchase.price(for: produkt))")
    }

    /// Die Ersparnis wird **ausgerechnet** und nicht behauptet: Eine Zahl, die
    /// jemand nachrechnen kann, trägt weiter als das Wort „günstiger".
    private var ersparnis: String {
        let einzeln = ProductID.individually.reduce(Decimal(0)) { $0 + $1.suggestedPrice }
        let gespart = einzeln - ProductID.everything.suggestedPrice
        guard gespart > 0 else { return "Alle vier Freischaltungen zusammen, dauerhaft." }
        let betrag = gespart.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
        return "Alle vier zusammen — \(betrag) günstiger als einzeln."
    }
}

#Preview {
    StoreView()
        .environment(Purchase())
}
