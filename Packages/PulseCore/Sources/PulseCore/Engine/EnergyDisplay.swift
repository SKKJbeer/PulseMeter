import Foundation

/// Gas und Heizöl in kWh, neben der Zahl vom Zähler.
///
/// Wer von Gas oder Öl auf eine Wärmepumpe wechselt, will kWh neben kWh sehen.
/// m³ und Liter bleiben die Hauptzahl, weil sie am Zähler stehen; die kWh
/// kommen dazu, sobald eine Umrechnung hinterlegt ist.
///
/// **Heizöl ohne neues Feld.** Der Heizwert steht im Tarif als
/// ``GasConversion`` mit Zustandszahl 1 und Brennwert in kWh je m³
/// (10 kWh/l = 10.000 kWh/m³). Ein eigenes Feld bräuchte ein neues
/// CloudKit-Schema und damit einen Deploy in der Konsole. Die Kosten berührt
/// das nicht: ``CostEngine`` rechnet nur über Dimensionen hinweg um, und Liter
/// gegen Liter ist dieselbe. Damit niemand außerhalb wissen muss, wie es
/// gespeichert ist, gehen alle Zugriffe durch diesen Typ.
public enum EnergyDisplay {

    /// Üblicher Heizwert von Heizöl EL. Auf keiner Rechnung angegeben, darum
    /// immer eine Schätzung (Produktprinzip 7).
    public static let typicalHeatingOilKWhPerLitre: Decimal = 10

    /// Der Heizwert als Umrechnung, wie er im Tarif gespeichert wird.
    public static func heatingOilConversion(kWhPerLitre: Decimal) -> GasConversion {
        GasConversion(stateNumber: 1, calorificValue: kWhPerLitre * 1000)
    }

    /// Der Heizwert in kWh je Liter aus einer gespeicherten Umrechnung.
    public static func kWhPerLitre(_ conversion: GasConversion) -> Decimal {
        conversion.stateNumber * conversion.calorificValue / 1000
    }

    /// Ob die kWh einer Einheit auf einer Annahme beruhen. Bei Gas stehen
    /// Zustandszahl und Brennwert auf der Rechnung, bei Heizöl nicht.
    public static func isEstimate(unit: MeasurementUnit) -> Bool {
        unit == .litre
    }

    /// Eine Menge in kWh mit der Umrechnung des Tarifs.
    ///
    /// `nil`, wenn die Menge kein Volumen ist (Strom ist schon kWh) oder der
    /// Tarif keine Umrechnung hat.
    public static func kilowattHours(for quantity: Quantity, tariff: Tariff?) -> Quantity? {
        guard quantity.unit.dimension == .volume,
              let conversion = tariff?.gasConversion,
              let energy = try? conversion.energy(fromVolume: quantity)
        else { return nil }
        return energy
    }

    /// Der Verbrauch eines Zählwerks im Zeitraum in kWh, **je Preisabschnitt
    /// mit der Umrechnung, die dort galt.** Ändert sich der Brennwert mit der
    /// neuen Rechnung, trägt man ihn als neuen Preis ab einem Tag ein, und die
    /// Vergangenheit bleibt richtig.
    ///
    /// `nil`, sobald einem Abschnitt die Umrechnung fehlt: Eine Summe, in der
    /// ein Teil fehlt, sähe vollständig aus und wäre es nicht.
    public static func kilowattHours(
        register: Register,
        readings: [Reading],
        tariffs: [Tariff],
        in range: DayRange
    ) -> Quantity? {
        guard register.unit.dimension == .volume,
              let segments = try? CostEngine.segmentsOfValidity(
                for: register, tariffs: tariffs, in: range),
              !segments.isEmpty,
              let series = ConsumptionSeries.build(register: register, readings: readings)
        else { return nil }
        var total = Decimal(0)
        for (segmentRange, tariff) in segments {
            let consumed = ConsumptionEngine.consumption(series: series, in: segmentRange)
            if consumed.quantity.value == 0 { continue }
            guard let energy = kilowattHours(for: consumed.quantity, tariff: tariff) else { return nil }
            total += energy.value
        }
        return Quantity(total, .kilowattHour)
    }
}
