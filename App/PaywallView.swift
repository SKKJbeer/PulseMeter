import SwiftUI
import PulseCore
import PulseUI

/// Ein Kaufblatt für **eine** Funktion.
///
/// **Warum kein Laden.** Ein eigener Schirm mit allen Produkten wäre ein Ort,
/// den niemand aufsucht. Gekauft wird dort, wo etwas fehlt: Wer am dritten
/// Zähler steht, bekommt den dritten Zähler angeboten — mit einem Preis und
/// einem Knopf. Alles andere steht als eine Zeile darunter, nicht als Regal.
///
/// **Sie erklärt, statt zu drängen.** Kein Countdown, keine durchgestrichenen
/// Preise. Die Zielgruppe öffnet diese App sechsmal im Jahr und reagiert auf
/// Verkaufsdruck mit einem Stern.
struct UnlockSheet: View {

    /// Die Funktion, an der der Nutzer gerade stand.
    let product: ProductID

    @Environment(Purchase.self) private var purchase
    @Environment(\.dismiss) private var dismiss

    /// Ob das Bündel überhaupt einen Sinn hat.
    ///
    /// Wer schon alles hat, bekommt es nicht angeboten — und wer das Bündel
    /// kauft, sieht es danach nicht mehr.
    private var showsBundle: Bool {
        !purchase.allows(.everything)
            && ProductID.individually.contains { !purchase.allows($0) && $0 != product }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    buyButton(for: product, prominent: true)
                    if showsBundle { bundle }
                    freeForever
                    if let problem = purchase.problem {
                        StatusBanner(tone: .notice, message: AttributedString(problem))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle(product.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Auf einem neuen Gerät der einzige Weg an die Käufe — und
                    // Apple verlangt ihn ohnehin in jeder App mit Kauf.
                    Button("Wiederherstellen") {
                        Task { await purchase.restore() }
                    }
                    .font(PulseText.caption)
                }
            }
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.explanation)
                .font(.system(.body))
                .foregroundStyle(PulseColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            // Kein Abo, und das ist bei sechs Öffnungen im Jahr das stärkste
            // Argument, das dieses Produkt hat.
            Text("Einmal kaufen, für immer behalten. Kein Abo, keine laufenden Kosten — auf allen deinen Geräten.")
                .font(PulseText.detail)
                .foregroundStyle(PulseColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func buyButton(for item: ProductID, prominent: Bool) -> some View {
        Button {
            Task { await purchase.buy(item) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prominent ? "Freischalten" : item.title)
                        .font(.system(.body, weight: .semibold))
                    if !prominent {
                        Text(item.explanation)
                            .font(PulseText.caption)
                            .opacity(0.85)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Text(purchase.price(for: item))
                    .font(.system(.body, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(prominent ? PulseColor.onAccent : PulseColor.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(prominent ? PulseColor.tint : PulseColor.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(prominent ? .clear : PulseColor.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(purchase.isWorking || !purchase.gateway.isAvailable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title) freischalten für \(purchase.price(for: item))")
        .accessibilityAddTraits(.isButton)
    }

    /// Das Bündel, und was es spart.
    ///
    /// Die Ersparnis wird **ausgerechnet** und nicht behauptet: Eine Zahl, die
    /// jemand nachrechnen kann, trägt weiter als das Wort „günstiger".
    private var bundle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Oder gleich alles")
                .pulseSectionLabel()
            buyButton(for: .everything, prominent: false)
            Text(savingsNote)
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)
        }
    }

    private var savingsNote: String {
        let single = ProductID.individually.reduce(Decimal(0)) { $0 + $1.suggestedPrice }
        let saved = single - ProductID.everything.suggestedPrice
        guard saved > 0 else { return "Alle vier Freischaltungen zusammen." }
        let formatted = saved.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
        return "Alle vier Freischaltungen zusammen — \(formatted) günstiger als einzeln."
    }

    /// Was kostenlos bleibt — und zwar dauerhaft.
    ///
    /// Der Absatz gehört auf die Kaufseite und nicht ins Kleingedruckte: Die
    /// häufigste Sorge bei Zähler-Apps ist nicht der Preis, sondern die Angst,
    /// später nicht mehr an die eigenen Zahlen zu kommen. Sie steht deshalb
    /// direkt neben dem Knopf, der Geld kostet.
    private var freeForever: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Dauerhaft kostenlos")
                .pulseSectionLabel()
            Text("Zwei Zähler, unbegrenzt viele Ablesungen, die ganze Historie, der Vorjahresvergleich, Erinnerungen — und der Export deiner Daten als Tabelle. Der Export bleibt kostenlos, auch wenn du nie kaufst.")
                .font(PulseText.detail)
                .foregroundStyle(PulseColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !purchase.gateway.isAvailable {
                // **Kein Knopf, der nichts tut.** Solange die App nicht im
                // Store ist, gibt es nichts zu kaufen; die Knöpfe oben sind
                // deshalb abgeblendet, und hier steht, warum.
                StatusBanner(
                    tone: .notice,
                    message: AttributedString("Kaufen geht, sobald PulseMeter im App Store ist. Bis dahin sind die Preise Richtwerte.")
                )
                .padding(.top, 6)
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Sperren

/// Eine gesperrte Zeile in einem Formular.
///
/// Sie zeigt, **dass** es die Funktion gibt, statt sie zu verstecken. Das ist
/// der Unterschied zwischen einer Grenze, die qualifiziert, und einer, die
/// blockiert: Wer den Abschnitt „Preise" nie sieht, vermisst ihn nicht — und
/// kauft auch nicht. Der Preis steht dabei, damit niemand erst tippen muss,
/// um zu erfahren, was es kostet.
struct ProLockRow: View {

    let product: ProductID
    let onTap: () -> Void

    @Environment(Purchase.self) private var purchase

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "lock")
                    .accessibilityHidden(true)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PulseColor.tintInk)
                    .frame(width: 20, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.title)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(PulseColor.ink)
                    Text(product.explanation)
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                PriceBadge(product: product)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Ein Element, ein Satz, ein klarer Hinweis. Ohne das läse VoiceOver
        // Titel, Erklärung und Preis als drei Fundstücke vor, und niemand
        // wüsste, dass die Zeile antippbar ist.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(product.title). \(product.explanation)")
        .accessibilityValue("Freischalten für \(purchase.price(for: product))")
        .accessibilityHint("Doppeltippen, um es freizuschalten")
        .accessibilityAddTraits(.isButton)
    }
}

/// Der Preis an einer gesperrten Stelle.
///
/// Bis 0.40.0 stand hier „Pro". Ein Wort, das nichts kostet, weckt die
/// Erwartung eines großen Kaufs; drei Euro sind kein großer Kauf, und das soll
/// man sehen, bevor man tippt.
struct PriceBadge: View {

    let product: ProductID
    @Environment(Purchase.self) private var purchase

    var body: some View {
        Text(purchase.price(for: product))
            .font(.system(.caption2, weight: .bold).monospacedDigit())
            .foregroundStyle(PulseColor.noticeInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PulseColor.noticeBackground, in: Capsule())
            // Der Preis steht schon in der Beschriftung der Zeile darüber.
            .accessibilityHidden(true)
    }
}
