import SwiftUI
import PulseCore
import PulseUI

/// Die Kaufseite.
///
/// **Sie erklärt, statt zu drängen.** Kein Countdown, keine durchgestrichenen
/// Preise, kein „nur heute": Die Zielgruppe öffnet diese App sechsmal im Jahr
/// und reagiert auf Verkaufsdruck mit einem Stern. Was hier steht, ist eine
/// Liste dessen, was der Kauf bringt — und ein Satz darüber, dass das
/// Kostenlose kostenlos bleibt.
///
/// Aufgerufen wird sie immer aus einer Sperre heraus, nie von selbst. Deshalb
/// weiß sie, **welche** Leistung gerade gefehlt hat, und stellt sie nach oben:
/// Wer am dritten Zähler hängt, will nicht über PDF-Berichte lesen.
struct PaywallView: View {

    /// Die Leistung, an der der Nutzer gerade stand. Sie steht zuerst.
    let reason: ProFeature?

    @Environment(Purchase.self) private var purchase
    @Environment(\.dismiss) private var dismiss

    /// Zuerst der Grund, dann der Rest in fester Reihenfolge — die Liste soll
    /// bei jedem Aufruf gleich aussehen, sonst sucht man beim zweiten Mal.
    private var features: [ProFeature] {
        guard let reason else { return ProFeature.allCases }
        return [reason] + ProFeature.allCases.filter { $0 != reason }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                            if index > 0 { Divider().overlay(PulseColor.hairline) }
                            row(for: feature, isReason: feature == reason)
                        }
                    }
                    .background(PulseColor.surface,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PulseColor.hairlineStrong, lineWidth: 1)
                    )

                    freeForever
                    purchaseArea
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(PulseColor.ground)
            .navigationTitle("PulseMeter Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Einmal kaufen, für immer behalten")
                .font(PulseText.cardTitle)
                .foregroundStyle(PulseColor.ink)
            // Kein Abo, und das ist das stärkste Verkaufsargument, das dieses
            // Produkt hat. Es steht deshalb im ersten Satz und nicht im
            // Kleingedruckten.
            Text("Kein Abo. Keine laufenden Kosten. Der Kauf gilt auf allen deinen Geräten und bleibt, solange du die App behältst.")
                .font(PulseText.detail)
                .foregroundStyle(PulseColor.inkSecondary)
        }
        .padding(.top, 4)
    }

    private func row(for feature: ProFeature, isReason: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "checkmark")
                .accessibilityHidden(true)
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(PulseColor.tint)
                .frame(width: 18, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(.body, weight: isReason ? .semibold : .medium))
                    .foregroundStyle(PulseColor.ink)
                Text(feature.explanation)
                    .font(PulseText.detail)
                    .foregroundStyle(PulseColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        // Ein Element je Leistung: Titel und Erklärung gehören zusammen, und
        // das Häkchen sagt nichts, was die Liste nicht schon sagt.
        .accessibilityElement(children: .combine)
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
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var purchaseArea: some View {
        if purchase.gateway.isAvailable {
            VStack(spacing: 10) {
                Button {
                    Task { await purchase.buy() }
                } label: {
                    Text(purchase.gateway.displayPrice.map { "Pro kaufen — \($0)" } ?? "Pro kaufen")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(PulseColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PulseColor.tint,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(purchase.isWorking)

                Button("Kauf wiederherstellen") {
                    Task { await purchase.restore() }
                }
                .font(PulseText.caption)
                .foregroundStyle(PulseColor.inkTertiary)
            }
        } else {
            // **Kein Knopf, der nichts tut.** Solange die App nicht im Store
            // ist, gibt es nichts zu kaufen; ein Knopf, der daraufhin eine
            // Fehlermeldung zeigt, wäre eine Falle. Der Satz sagt stattdessen,
            // woran es liegt.
            StatusBanner(
                tone: .notice,
                message: AttributedString("Der Kauf steht bereit, sobald PulseMeter im App Store ist. Bis dahin ist alles hier kostenlos zu sehen, aber noch nicht zu kaufen.")
            )
        }

        if let problem = purchase.problem {
            StatusBanner(tone: .notice, message: AttributedString(problem))
        }
    }
}

// MARK: - Sperren

/// Eine gesperrte Zeile in einem Formular.
///
/// Sie zeigt, **dass** es die Leistung gibt, statt sie zu verstecken. Das ist
/// der Unterschied zwischen einer Grenze, die qualifiziert, und einer, die
/// blockiert: Wer den Abschnitt „Preise" nie sieht, vermisst ihn nicht — und
/// kauft auch nicht.
struct ProLockRow: View {

    let feature: ProFeature
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "lock")
                    .accessibilityHidden(true)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PulseColor.tint)
                    .frame(width: 20, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(PulseColor.ink)
                    Text(feature.explanation)
                        .font(PulseText.detail)
                        .foregroundStyle(PulseColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                ProBadge()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        // Ein Element, ein Satz, ein klarer Hinweis. Ohne das läse VoiceOver
        // Titel, Erklärung und das Wort „Pro" als drei Fundstücke vor, und
        // niemand wüsste, dass die Zeile antippbar ist.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.title). \(feature.explanation)")
        .accessibilityValue("Mit Pro")
        .accessibilityHint("Doppeltippen, um PulseMeter Pro anzusehen")
        .accessibilityAddTraits(.isButton)
    }
}

/// Das kleine Wort „Pro" an einer gesperrten Stelle.
struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(PulseColor.noticeInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PulseColor.noticeBackground,
                        in: Capsule())
            // Der Text steht schon in der Beschriftung der Zeile darüber.
            .accessibilityHidden(true)
    }
}
