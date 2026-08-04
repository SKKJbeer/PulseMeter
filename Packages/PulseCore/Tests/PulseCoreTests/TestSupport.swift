import Foundation
import XCTest
@testable import PulseCore

func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> CalendarDay {
    CalendarDay(year: year, month: month, day: dayOfMonth)!
}

func span(_ start: CalendarDay, _ end: CalendarDay) -> DayRange {
    DayRange(start: start, end: end)!
}

func dec(_ literal: String) -> Decimal {
    Decimal(string: literal)!
}

/// Für Vergleiche mit Toleranz. `Decimal` ist exakt; Interpolationen erzeugen
/// aber periodische Brüche, die sich nicht als Literal schreiben lassen.
func approx(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}

func assertClose(
    _ value: Decimal,
    _ expected: Double,
    accuracy: Double = 0.0001,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(approx(value), expected, accuracy: accuracy, message, file: file, line: line)
}

// MARK: - Fixtures

enum Fixture {

    static let property = Property(name: "Zuhause")

    /// Sechsstelliges Stromzählwerk mit einer Nachkommastelle.
    static func electricityRegister() -> Register {
        Register(unit: .kilowattHour, integerDigits: 6, fractionDigits: 1)
    }

    /// Fünfstelliges Gaszählwerk in m³.
    static func gasRegister() -> Register {
        Register(unit: .cubicMetre, integerDigits: 5, fractionDigits: 3)
    }

    static func reading(
        _ register: Register,
        _ readingDay: CalendarDay,
        _ value: Decimal,
        device: MeterDevice? = nil,
        origin: ReadingOrigin = .manual,
        sequence: Int = 0
    ) -> Reading {
        Reading(
            registerID: register.id,
            deviceID: device?.id,
            day: readingDay,
            value: value,
            origin: origin,
            createdAt: Date(timeIntervalSince1970: TimeInterval(sequence))
        )
    }

    static func meteringPoint(registers: [Register], kind: ResourceKind = .electricity) -> MeteringPoint {
        MeteringPoint(propertyID: property.id, name: "Strom", kind: kind, registers: registers)
    }
}
