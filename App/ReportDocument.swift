import SwiftUI
import PulseCore

/// Der Verbrauchsbericht als Dokument.
///
/// **Warum eigene Seiten und keine lange Bahn.** Der Bericht wird gedruckt und
/// neben die Jahresabrechnung gelegt — das ist sein ganzer Zweck. Eine
/// PDF-Seite von drei Metern Länge erfüllt ihn nicht.
///
/// Jede Seite wird für sich gerendert und als eigene PDF-Seite geschrieben.
/// Der naheliegende Weg wäre gewesen, das ganze Dokument einmal zu rendern und
/// den Zeichenkontext seitenweise zu verschieben — dabei entscheidet aber eine
/// Koordinatenverschiebung über das Ergebnis, und ein Vorzeichenfehler darin
/// fällt in keiner Prüfung auf, sondern erst dem Nutzer beim Öffnen. Seite für
/// Seite kostet mehr Code und hat keine Rechnung, die falsch sein kann.
///
/// Bewusst nicht im Design-System der App: Ein Dokument ist Papier. Es ist
/// immer hell, immer schwarz auf weiß, und es ändert sich nicht mit dem
/// Erscheinungsbild des Geräts.
enum ReportPaper {
    /// A4 in Punkten — 72 dpi, wie PDF sie zählt.
    static let pageWidth: CGFloat = 595
    static let pageHeight: CGFloat = 842
    static let margin: CGFloat = 46

    static let ink = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let inkSoft = Color(red: 0.42, green: 0.40, blue: 0.35)
    static let inkFaint = Color(red: 0.62, green: 0.60, blue: 0.55)
    static let rule = Color(red: 0.85, green: 0.84, blue: 0.80)
    static let paper = Color.white
    static let less = Color(red: 0.13, green: 0.45, blue: 0.28)
    static let more = Color(red: 0.62, green: 0.20, blue: 0.16)
}

/// Eine Seite des Berichts.
///
/// Der Schnitt liegt an Abschnittsgrenzen, nie mitten in einer Zeile: Ein
/// halber Tabellenwert über zwei Seiten ist der Unterschied zwischen einem
/// Dokument und einem Ausdruck.
enum ReportPage: Identifiable {
    case summary(ReportBuilder.Report)
    case meter(ReportBuilder.MeterSection, months: [ReportBuilder.MonthLine], part: Int, parts: Int)
    case notes(ReportBuilder.Report)

    var id: String {
        switch self {
        case .summary: return "summary"
        case .meter(let section, _, let part, _): return "meter-\(section.id)-\(part)"
        case .notes: return "notes"
        }
    }

    /// Zerlegt einen Bericht in Seiten.
    ///
    /// Eine Monatstabelle hat höchstens zwölf Zeilen und passt damit immer auf
    /// eine Seite. Die Aufteilung steht trotzdem da: Ein Bericht über
    /// „Letzte 12 Monate" bei einem Zeitraum über den Jahreswechsel kann
    /// dreizehn Zeilen haben, und ein Bericht, der bei dreizehn Zeilen
    /// abschneidet, wäre falsch statt lang.
    static func pages(for report: ReportBuilder.Report, rowsPerPage: Int = 16) -> [ReportPage] {
        var pages: [ReportPage] = [.summary(report)]
        for section in report.sections {
            let chunks = section.months.isEmpty
                ? [[ReportBuilder.MonthLine]()]
                : stride(from: 0, to: section.months.count, by: rowsPerPage).map {
                    Array(section.months[$0..<min($0 + rowsPerPage, section.months.count)])
                }
            for (index, chunk) in chunks.enumerated() {
                pages.append(.meter(section, months: chunk, part: index, parts: chunks.count))
            }
        }
        pages.append(.notes(report))
        return pages
    }
}

// MARK: - Die Seiten

struct ReportPageView: View {

    let page: ReportPage
    let pageNumber: Int
    let pageCount: Int
    /// Ob quer über die Seite ein Wasserzeichen liegt.
    ///
    /// **Warum ein Wasserzeichen und keine Sperre.** Der Bericht lässt sich
    /// ansehen, blättern und drucken, auch ohne ihn gekauft zu haben — man
    /// sieht also vorher, was man bekommt, statt vor einem Schloss zu stehen.
    /// Bezahlt wird für das, was man weitergeben will: Ein Dokument mit einem
    /// Schriftzug quer darüber legt niemand seinem Vermieter vor.
    ///
    /// Das ist zugleich die ehrlichere Bezahlschranke. Wer nur für sich
    /// nachsehen will, ob die Abrechnung stimmt, zahlt nichts.
    var watermarked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(ReportPaper.margin)
        .frame(width: ReportPaper.pageWidth, height: ReportPaper.pageHeight, alignment: .topLeading)
        .background(ReportPaper.paper)
        .overlay { if watermarked { watermark } }
        .environment(\.colorScheme, .light)
    }

    /// Der Schriftzug quer über die Seite.
    ///
    /// Diagonal, groß und blass: **lesbar genug, dass ein Empfänger ihn nicht
    /// übersieht, blass genug, dass die Zahlen darunter zu lesen bleiben.**
    /// Ein Wasserzeichen, das den Bericht unbrauchbar macht, ist eine Sperre
    /// mit Umweg — und dann wäre eine Sperre ehrlicher.
    ///
    /// `allowsHitTesting(false)`, damit es beim Blättern nicht im Weg liegt,
    /// und für VoiceOver ausgeblendet: Es steht auf jeder Seite, und dreimal
    /// „Nicht freigeschaltete Vorschau" vorgelesen zu bekommen, hilft niemandem.
    /// Die Zeile über der Vorschau sagt dasselbe einmal.
    private var watermark: some View {
        Text("PulseMeter · Vorschau")
            .font(.system(size: 46, weight: .semibold))
            .foregroundStyle(ReportPaper.ink.opacity(0.11))
            .rotationEffect(.degrees(-32))
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .summary(let report): summaryPage(report)
        case .meter(let section, let months, let part, let parts):
            meterPage(section, months: months, part: part, parts: parts)
        case .notes(let report): notesPage(report)
        }
    }

    private var footer: some View {
        HStack {
            Text("PulseMeter")
            Spacer()
            Text("Seite \(pageNumber) von \(pageCount)")
        }
        .font(.system(size: 8))
        .foregroundStyle(ReportPaper.inkFaint)
        .padding(.top, 14)
    }

    // MARK: Zusammenfassung

    private func summaryPage(_ report: ReportBuilder.Report) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Verbrauchsbericht")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(ReportPaper.ink)
            Text("\(report.period.label) · \(rangeText(report.period))")
                .font(.system(size: 10.5))
                .foregroundStyle(ReportPaper.inkSoft)
                .padding(.top, 5)
            Text("\(report.propertyName) · \(meterCountText(report)) · erstellt am \(longDate(report.createdOn))")
                .font(.system(size: 10.5))
                .foregroundStyle(ReportPaper.inkSoft)
                .padding(.top, 2)

            Rectangle().fill(ReportPaper.ink).frame(height: 1.4).padding(.top, 12)

            heading("Zusammenfassung").padding(.top, 20)

            if let total = report.totalCost {
                amountRow("Kosten im Zeitraum · \(report.sections.count) Zähler", total)
            }
            if let onAccount = report.costOnAccount, let paid = report.prepaymentTotal,
               let balance = report.balance {
                amountRow("davon über Abschlag abgerechnet · \(report.namesOnAccount.joined(separator: " und "))",
                          onAccount)
                amountRow("Gezahlte Abschläge", paid)
                amountRow(balance.amount >= 0 ? "Guthaben" : "Nachzahlung",
                          Money(abs(balance.amount), balance.currency), emphasised: true)
            }

            heading("Zähler in diesem Bericht").padding(.top, 24)
            ForEach(report.sections) { section in
                HStack(alignment: .firstTextBaseline) {
                    Text(section.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ReportPaper.ink)
                    if !section.isComplete {
                        Text("bis \(shortDate(section.consumption.coveredRange?.end ?? report.period.range.end))")
                            .font(.system(size: 9))
                            .foregroundStyle(ReportPaper.inkFaint)
                    }
                    Spacer(minLength: 8)
                    Text(quantityText(section.consumption.quantity))
                        .font(.system(size: 11))
                        .foregroundStyle(ReportPaper.ink)
                    if let total = section.total {
                        Text(moneyText(total))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ReportPaper.ink)
                            .frame(width: 78, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
                Rectangle().fill(ReportPaper.rule).frame(height: 0.6)
            }
        }
    }

    // MARK: Ein Zähler

    private func meterPage(
        _ section: ReportBuilder.MeterSection,
        months: [ReportBuilder.MonthLine],
        part: Int,
        parts: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heading(parts > 1 ? "\(section.name) (\(part + 1)/\(parts))" : section.name)

            if part == 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(quantityText(section.consumption.quantity))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(ReportPaper.ink)
                    Text("im Zeitraum")
                        .font(.system(size: 10))
                        .foregroundStyle(ReportPaper.inkSoft)
                }
                .padding(.top, 8)

                if let serial = section.serialNumber {
                    Text("Zählernummer \(serial)")
                        .font(.system(size: 9.5))
                        .foregroundStyle(ReportPaper.inkSoft)
                        .padding(.top, 3)
                }
                ForEach(section.registers) { line in
                    if let start = line.startValue, let end = line.endValue,
                       let covered = section.consumption.coveredRange {
                        Text(standText(line, start: start, end: end, covered: covered))
                            .font(.system(size: 9.5))
                            .foregroundStyle(ReportPaper.inkSoft)
                            .padding(.top, 1)
                    }
                }
                if !section.isComplete {
                    Text("Der Zeitraum reicht weiter als die vorliegenden Ablesungen. Es wird nicht hochgerechnet.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(ReportPaper.inkFaint)
                        .padding(.top, 3)
                }
            }

            if !months.isEmpty {
                monthTable(section, months: months, showTotal: part == parts - 1)
                    .padding(.top, 16)
            }

            if part == parts - 1 {
                costBlock(section).padding(.top, 14)
            }
        }
    }

    private func monthTable(
        _ section: ReportBuilder.MeterSection,
        months: [ReportBuilder.MonthLine],
        showTotal: Bool
    ) -> some View {
        let digits = section.consumption.quantity.unit == .cubicMetre ? 1 : 0
        return VStack(spacing: 0) {
            HStack {
                Text("Monat").frame(maxWidth: .infinity, alignment: .leading)
                Text("Wert").frame(width: 88, alignment: .trailing)
                Text("Vorjahr").frame(width: 88, alignment: .trailing)
                Text("Δ").frame(width: 62, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(ReportPaper.inkSoft)
            .padding(.bottom, 5)
            Rectangle().fill(ReportPaper.ink).frame(height: 0.8)

            ForEach(months) { line in
                HStack {
                    Text("\(monthName(line.month)) \(String(String(line.year).suffix(2)))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(number(line.value, digits: digits)).frame(width: 88, alignment: .trailing)
                    Text(line.previousValue.map { number($0, digits: digits) } ?? "—")
                        .foregroundStyle(ReportPaper.inkFaint)
                        .frame(width: 88, alignment: .trailing)
                    Text(line.relativeChange.map { percent($0) } ?? "—")
                        .foregroundStyle(changeColour(line.relativeChange))
                        .frame(width: 62, alignment: .trailing)
                }
                .font(.system(size: 10))
                .foregroundStyle(ReportPaper.ink)
                .padding(.vertical, 3.5)
                Rectangle().fill(ReportPaper.rule).frame(height: 0.5)
            }

            if showTotal {
                HStack {
                    Text("Zeitraum").frame(maxWidth: .infinity, alignment: .leading)
                    Text(number(section.consumption.quantity.value, digits: digits))
                        .frame(width: 88, alignment: .trailing)
                    Text(section.previous.map { number($0.quantity.value, digits: digits) } ?? "—")
                        .foregroundStyle(ReportPaper.inkFaint)
                        .frame(width: 88, alignment: .trailing)
                    Text(section.relativeChange.map { percent($0) } ?? "—")
                        .foregroundStyle(changeColour(section.relativeChange))
                        .frame(width: 62, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ReportPaper.ink)
                .padding(.top, 5)
            }
        }
    }

    private func costBlock(_ section: ReportBuilder.MeterSection) -> some View {
        VStack(spacing: 0) {
            ForEach(section.registers.filter { !$0.isFeedIn }) { line in
                if let amount = line.amount, let price = line.pricePerUnit {
                    amountRow(workLabel(line, section: section, price: price), amount)
                }
            }
            if let feedIn = section.feedInAmount, feedIn.amount != 0 {
                amountRow("Einspeisevergütung", Money(-abs(feedIn.amount), feedIn.currency))
            }
            if let base = section.baseAmount, base.amount != 0 {
                amountRow("Grundpreis · \(section.consumption.coveredDays) Tage", base)
            }
            if let total = section.total {
                amountRow("Kosten \(section.name)", total, emphasised: true)
            }
        }
    }

    // MARK: Hinweise

    private func notesPage(_ report: ReportBuilder.Report) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Wie diese Zahlen entstehen")
            Text(explanation(report))
                .font(.system(size: 10))
                .foregroundStyle(ReportPaper.inkSoft)
                .lineSpacing(2.5)
            heading("Dieser Bericht ersetzt keine Abrechnung").padding(.top, 8)
            Text("""
                 Er dient dazu, die Abrechnung deines Versorgers nachzuvollziehen und zu prüfen. \
                 Maßgeblich bleibt die Rechnung des Versorgers.
                 """)
                .font(.system(size: 10))
                .foregroundStyle(ReportPaper.inkSoft)
                .lineSpacing(2.5)
        }
    }

    private func explanation(_ report: ReportBuilder.Report) -> String {
        var text = "Verbräuche sind die Differenz abgelesener Zählerstände. "
        if report.hasIncompleteData {
            text += "Wo die letzte Ablesung vor dem Ende des Zeitraums liegt, endet der Zeitraum dort — "
                 + "es wird nicht hochgerechnet. "
        }
        if report.hasEstimatedReadings {
            text += "Als geschätzt erfasste Ablesungen fließen mit ein und sind im Verlauf gekennzeichnet. "
        }
        if report.sections.contains(where: { $0.registers.count > 1 }) {
            text += "Führt ein Zähler mehrere Zahlen — etwa getrennt für Tag und Nacht —, wird über den "
                 + "Zeitausschnitt gerechnet, den alle abdecken, und jede Zahl mit ihrem eigenen Preis. "
                 + "Der Grundpreis fällt einmal je Zähler an. "
        }
        text += "Gas wird in m³ gemessen und mit Zustandszahl und Brennwert in kWh umgerechnet; beide "
             + "Werte stammen aus deiner Jahresrechnung. Vergleiche mit dem Vorjahr verwenden immer "
             + "denselben Zeitausschnitt. "
        if report.balance != nil {
            text += "In den Saldo fließen nur Zähler mit hinterlegtem Abschlag; alle übrigen sind in den "
                 + "Gesamtkosten enthalten, werden aber getrennt bezahlt."
        }
        return text
    }

    // MARK: Bausteine

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(ReportPaper.ink)
    }

    private func amountRow(_ label: String, _ amount: Money, emphasised: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: emphasised ? 11 : 10, weight: emphasised ? .semibold : .regular))
                    .foregroundStyle(emphasised ? ReportPaper.ink : ReportPaper.inkSoft)
                Spacer(minLength: 10)
                Text(moneyText(amount))
                    .font(.system(size: emphasised ? 12 : 10.5, weight: emphasised ? .semibold : .medium))
                    .foregroundStyle(ReportPaper.ink)
            }
            .padding(.vertical, 4)
            Rectangle().fill(emphasised ? ReportPaper.ink : ReportPaper.rule)
                .frame(height: emphasised ? 0.9 : 0.5)
        }
    }

    private func workLabel(
        _ line: ReportBuilder.RegisterLine,
        section: ReportBuilder.MeterSection,
        price: Decimal
    ) -> String {
        let name = line.label.map { "Arbeitspreis \($0)" } ?? "Arbeitspreis"
        let digits = line.quantity.unit == .cubicMetre ? 1 : 0
        return "\(name) · \(number(line.quantity.value, digits: digits)) \(line.quantity.unit.symbol)"
             + " × \(number(price, digits: price < Decimal(string: "0.1")! ? 3 : 2)) €"
    }

    private func standText(
        _ line: ReportBuilder.RegisterLine,
        start: Decimal,
        end: Decimal,
        covered: DayRange
    ) -> String {
        let prefix = line.label.map { "\($0) · " } ?? ""
        return prefix
            + "Stand \(number(start, digits: line.fractionDigits)) am \(shortDate(covered.start))"
            + " bis \(number(end, digits: line.fractionDigits)) am \(shortDate(covered.end))"
    }

    private func changeColour(_ change: Decimal?) -> Color {
        guard let change else { return ReportPaper.inkFaint }
        return change < 0 ? ReportPaper.less : ReportPaper.more
    }

    private func meterCountText(_ report: ReportBuilder.Report) -> String {
        report.sections.count == 1 ? report.sections[0].name : "\(report.sections.count) Zähler"
    }

    private func rangeText(_ period: ReportBuilder.Period) -> String {
        "\(longDate(period.range.start)) bis \(longDate(period.lastIncludedDay))"
    }

    // MARK: Formate

    private func quantityText(_ quantity: Quantity) -> String {
        let digits = quantity.unit == .cubicMetre ? 1 : 0
        return "\(number(quantity.value, digits: digits)) \(quantity.unit.symbol)"
    }

    private func moneyText(_ money: Money) -> String {
        money.amount.formatted(.currency(code: money.currency.code).locale(Locale(identifier: "de_DE")))
    }

    private func number(_ value: Decimal, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "de_DE")))
    }

    private func percent(_ value: Decimal) -> String {
        let sign = value > 0 ? "+" : ""
        return sign + (value * 100).formatted(.number.precision(.fractionLength(0))
            .locale(Locale(identifier: "de_DE"))) + " %"
    }

    private func monthName(_ month: Int) -> String {
        ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
         "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"][max(0, min(11, month - 1))]
    }

    private func date(_ day: CalendarDay) -> Date? {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: components)
    }

    private func longDate(_ day: CalendarDay) -> String {
        guard let date = date(day) else { return day.description }
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE")))
    }

    private func shortDate(_ day: CalendarDay) -> String {
        guard let date = date(day) else { return day.description }
        return date.formatted(.dateTime.day().month(.abbreviated).year()
            .locale(Locale(identifier: "de_DE")))
    }
}
