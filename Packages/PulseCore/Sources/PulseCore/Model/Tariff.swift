import Foundation

/// Umrechnung von Gasvolumen in Energie.
///
/// In Deutschland wird Gas in m³ gemessen, aber in kWh abgerechnet:
/// `kWh = m³ × Zustandszahl × Brennwert`
///
/// Beide Faktoren stehen auf der Jahresrechnung des Versorgers. Die Umrechnung
/// ist immer explizit — dem Nutzer zeigen wir m³, die Kosten rechnen wir in kWh,
/// und die Umrechnung ist in der Oberfläche antippbar erklärt (Produktprinzip 4).
public struct GasConversion: Hashable, Codable, Sendable {

    /// Zustandszahl (Z-Zahl), typisch etwa 0,95.
    public var stateNumber: Decimal
    /// Brennwert in kWh/m³, typisch etwa 10,0 bis 11,5.
    public var calorificValue: Decimal

    public init(stateNumber: Decimal, calorificValue: Decimal) {
        self.stateNumber = stateNumber
        self.calorificValue = calorificValue
    }

    /// Typische Werte als Startvorschlag. Der Nutzer soll sie durch die Werte
    /// seiner Rechnung ersetzen — die Vorbelegung ist eine Hilfe, keine Aussage.
    public static let typical = GasConversion(
        stateNumber: Decimal(string: "0.95")!,
        calorificValue: Decimal(string: "10.5")!
    )

    public func energy(fromVolume volume: Quantity) throws -> Quantity {
        let cubicMetres = try volume.converted(to: .cubicMetre)
        return Quantity(cubicMetres.value * stateNumber * calorificValue, .kilowattHour)
    }
}

/// Ein Tarif mit Gültigkeitszeitraum.
///
/// Tarife sind zeitlich versioniert: Ein Preiswechsel legt einen neuen Tarif an
/// und korrigiert nie den alten. Der Rechenkern teilt Zeiträume an Tarifgrenzen
/// und rechnet abschnittsweise — genau hier entstehen die Rechenfehler
/// vergleichbarer Apps.
public struct Tariff: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var meteringPointID: MeteringPoint.ID
    /// `nil` = gilt für alle Zählwerke der Messstelle. Bei Doppeltarif zeigt
    /// jeder Tarif auf sein Zählwerk.
    public var registerID: Register.ID?

    public var validFrom: CalendarDay
    /// `nil` = bis auf Weiteres gültig.
    public var validTo: CalendarDay?

    /// Arbeitspreis brutto je Einheit von ``billingUnit``.
    public var pricePerUnit: Decimal
    /// Grundpreis brutto je Monat.
    public var monthlyBasePrice: Decimal
    public var currency: CurrencyCode

    /// Einheit, in der abgerechnet wird. Bei Gas typischerweise kWh, obwohl das
    /// Zählwerk in m³ misst — dann ist ``gasConversion`` erforderlich.
    public var billingUnit: MeasurementUnit
    public var gasConversion: GasConversion?

    /// Vergütung je eingespeister Einheit. Nur für Zählwerke mit
    /// ``FlowDirection/feedIn`` relevant.
    public var feedInPricePerUnit: Decimal?

    public init(
        id: UUID = UUID(),
        meteringPointID: MeteringPoint.ID,
        registerID: Register.ID? = nil,
        validFrom: CalendarDay,
        validTo: CalendarDay? = nil,
        pricePerUnit: Decimal,
        monthlyBasePrice: Decimal = 0,
        currency: CurrencyCode = .eur,
        billingUnit: MeasurementUnit,
        gasConversion: GasConversion? = nil,
        feedInPricePerUnit: Decimal? = nil
    ) {
        self.id = id
        self.meteringPointID = meteringPointID
        self.registerID = registerID
        self.validFrom = validFrom
        self.validTo = validTo
        self.pricePerUnit = pricePerUnit
        self.monthlyBasePrice = monthlyBasePrice
        self.currency = currency
        self.billingUnit = billingUnit
        self.gasConversion = gasConversion
        self.feedInPricePerUnit = feedInPricePerUnit
    }

    public func isValid(on day: CalendarDay) -> Bool {
        day >= validFrom && (validTo.map { day <= $0 } ?? true)
    }

    /// Gültigkeitsbereich, begrenzt auf einen Zeitraum. `nil` ohne Überschneidung.
    public func validity(within range: DayRange) -> DayRange? {
        let start = Swift.max(validFrom, range.start)
        let end = validTo.map { Swift.min($0, range.end) } ?? range.end
        return DayRange(start: start, end: end)
    }
}

/// Ein Abrechnungszeitraum mit Abschlagszahlung.
///
/// Diese Entität macht aus einer Zahlensammlung ein Produkt: Erst sie erlaubt die
/// Aussage „Bei diesem Verbrauch liegst du am Jahresende 84 € im Plus."
/// Ohne sie wären wir eine Tabelle.
public struct BillingPeriod: Identifiable, Hashable, Codable, Sendable {

    public let id: UUID
    public var meteringPointID: MeteringPoint.ID
    public var provider: String?
    public var customerReference: String?
    public var range: DayRange
    /// Monatlicher Abschlag. `nil`, wenn der Nutzer ihn nicht hinterlegt hat.
    public var monthlyPrepayment: Decimal?
    public var currency: CurrencyCode

    public init(
        id: UUID = UUID(),
        meteringPointID: MeteringPoint.ID,
        provider: String? = nil,
        customerReference: String? = nil,
        range: DayRange,
        monthlyPrepayment: Decimal? = nil,
        currency: CurrencyCode = .eur
    ) {
        self.id = id
        self.meteringPointID = meteringPointID
        self.provider = provider
        self.customerReference = customerReference
        self.range = range
        self.monthlyPrepayment = monthlyPrepayment
        self.currency = currency
    }

    /// Länge des Zeitraums in Monaten, tagesgenau anteilig.
    ///
    /// Bewusst nicht „Anzahl angefangener Monate": Ein Zeitraum vom 15.01. bis
    /// 14.01. umfasst zwölf Monate, nicht dreizehn.
    public var lengthInMonths: Decimal {
        let days = Decimal(range.dayCount)
        let daysPerMonth = Decimal(CalendarDay.daysInYear(range.start.year)) / 12
        return days / daysPerMonth
    }

    /// Summe der Abschläge über den gesamten Zeitraum.
    public var totalPrepayment: Money? {
        guard let monthly = monthlyPrepayment else { return nil }
        return Money(monthly * lengthInMonths, currency)
    }
}
