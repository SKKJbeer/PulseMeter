import Foundation
import SwiftData
import PulseCore

/// Übersetzung zwischen gespeicherten Datensätzen und den Wertetypen der Domäne.
///
/// Die Richtung `Record → Domain` ist bewusst tolerant: Ein unlesbares Feld
/// führt zu einem Vorgabewert, nie zu einem Absturz oder zu verschwiegenen
/// Daten. Ein Nutzer darf durch einen fehlerhaften Datensatz höchstens eine
/// Einstellung verlieren, nie seine Ablesungen.
enum Mapping {

    static func day(_ raw: Int, fallback: CalendarDay = CalendarDay(year: 2000, month: 1, day: 1)!) -> CalendarDay {
        CalendarDay(rawValue: raw) ?? fallback
    }

    static func unit(_ raw: String) -> MeasurementUnit {
        MeasurementUnit(rawValue: raw) ?? .kilowattHour
    }
}

// MARK: - Property

extension PropertyRecord {
    func toDomain() -> Property {
        Property(id: id, name: name, street: street, postalCode: postalCode,
                 city: city, note: note, sortIndex: sortIndex)
    }

    func apply(_ value: Property) {
        id = value.id
        name = value.name
        street = value.street
        postalCode = value.postalCode
        city = value.city
        note = value.note
        sortIndex = value.sortIndex
    }
}

// MARK: - RentalUnit

extension RentalUnitRecord {
    func toDomain() -> RentalUnit {
        let occupancies: [OccupancyPeriod] = occupancyData
            .flatMap { try? JSONDecoder().decode([OccupancyPeriod].self, from: $0) } ?? []
        return RentalUnit(id: id, propertyID: property?.id ?? UUID(),
                          name: name, occupancies: occupancies, sortIndex: sortIndex)
    }

    func apply(_ value: RentalUnit) {
        id = value.id
        name = value.name
        sortIndex = value.sortIndex
        occupancyData = try? JSONEncoder().encode(value.occupancies)
    }
}

// MARK: - Register

extension RegisterRecord {
    func toDomain() -> Register {
        Register(
            id: id,
            label: label,
            unit: Mapping.unit(unitID),
            direction: FlowDirection(rawValue: directionID) ?? .consumption,
            accumulation: AccumulationMode(rawValue: accumulationID) ?? .cumulative,
            integerDigits: integerDigits,
            fractionDigits: fractionDigits,
            obisCode: obisCode
        )
    }

    func apply(_ value: Register, sortIndex index: Int) {
        id = value.id
        label = value.label
        unitID = value.unit.rawValue
        directionID = value.direction.rawValue
        accumulationID = value.accumulation.rawValue
        integerDigits = value.integerDigits
        fractionDigits = value.fractionDigits
        obisCode = value.obisCode
        sortIndex = index
    }
}

// MARK: - MeterDevice

extension MeterDeviceRecord {
    func toDomain() -> MeterDevice {
        MeterDevice(id: id, serialNumber: serialNumber,
                    installedOn: Mapping.day(installedOn),
                    removedOn: removedOn.flatMap { CalendarDay(rawValue: $0) },
                    photoID: photoID)
    }

    func apply(_ value: MeterDevice) {
        id = value.id
        serialNumber = value.serialNumber
        installedOn = value.installedOn.rawValue
        removedOn = value.removedOn?.rawValue
        photoID = value.photoID
    }
}

// MARK: - MeteringPoint

extension MeteringPointRecord {
    func toDomain() -> MeteringPoint {
        let cycle: BillingCycle? = {
            guard let month = billingAnchorMonth, let anchorDay = billingAnchorDay else { return nil }
            return BillingCycle(anchorMonth: month, anchorDay: anchorDay)
        }()
        let sortedRegisters = (registers ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { $0.toDomain() }

        return MeteringPoint(
            id: id,
            propertyID: property?.id ?? propertyID,
            unitID: unitID,
            name: name,
            kind: ResourceKind.restore(storageID: kindID,
                                       customName: customKindName,
                                       customUnit: customKindUnit.map(Mapping.unit)),
            appearance: Appearance(symbolName: symbolName, colorToken: colorToken),
            // Ein Zähler ohne Zählwerk wäre nicht bedienbar; im Zweifel eines
            // aus der Vorbelegung der Art, damit die Ansicht nicht leer bleibt.
            registers: sortedRegisters.isEmpty ? nil : sortedRegisters,
            devices: (devices ?? []).map { $0.toDomain() },
            readingInterval: ReadingInterval(rawValue: readingIntervalID) ?? .monthly,
            billingCycle: cycle,
            isArchived: isArchived,
            sortIndex: sortIndex,
            note: note
        )
    }

    /// Überträgt den Zustand und gleicht die Zählwerke ab.
    ///
    /// Zählwerke werden über ihre `id` zugeordnet, nicht ersetzt: Würde man sie
    /// löschen und neu anlegen, nähme die Löschregel `.cascade` sämtliche
    /// Ablesungen mit. Diese Zeile ist der Grund, warum es diese Methode gibt.
    func apply(_ value: MeteringPoint, in context: ModelContext) {
        id = value.id
        name = value.name
        kindID = value.kind.storageID
        customKindName = value.kind.customName
        customKindUnit = value.kind.customUnit?.rawValue
        symbolName = value.appearance.symbolName
        colorToken = value.appearance.colorToken
        readingIntervalID = value.readingInterval.rawValue
        billingAnchorMonth = value.billingCycle?.anchorMonth
        billingAnchorDay = value.billingCycle?.anchorDay
        isArchived = value.isArchived
        sortIndex = value.sortIndex
        note = value.note
        unitID = value.unitID
        propertyID = value.propertyID

        var existing = Dictionary(uniqueKeysWithValues: (registers ?? []).map { ($0.id, $0) })
        var kept: [RegisterRecord] = []
        for (index, register) in value.registers.enumerated() {
            let record = existing.removeValue(forKey: register.id) ?? {
                let fresh = RegisterRecord(id: register.id)
                context.insert(fresh)
                return fresh
            }()
            record.apply(register, sortIndex: index)
            kept.append(record)
        }
        for orphan in existing.values { context.delete(orphan) }
        registers = kept

        var existingDevices = Dictionary(uniqueKeysWithValues: (devices ?? []).map { ($0.id, $0) })
        var keptDevices: [MeterDeviceRecord] = []
        for device in value.devices {
            let record = existingDevices.removeValue(forKey: device.id) ?? {
                let fresh = MeterDeviceRecord(id: device.id)
                context.insert(fresh)
                return fresh
            }()
            record.apply(device)
            keptDevices.append(record)
        }
        for orphan in existingDevices.values { context.delete(orphan) }
        devices = keptDevices
    }
}

// MARK: - Reading

extension ReadingRecord {
    func toDomain() -> Reading {
        Reading(
            id: id,
            registerID: register?.id ?? registerID,
            deviceID: deviceID,
            day: Mapping.day(day),
            // `flatMap`, nicht `map`: Ein unmöglicher Wert — etwa 1500 Minuten
            // aus einem beschädigten Satz — soll „keine Uhrzeit" heißen und
            // nicht die Ablesung mitnehmen.
            time: timeMinutes.flatMap(TimeOfDay.init(minuteOfDay:)),
            value: ScaledDecimal(scaled: scaledValue, scale: valueScale).value,
            origin: ReadingOrigin(rawValue: originID) ?? .manual,
            note: note,
            photoID: photoID,
            createdAt: createdAt
        )
    }

    func apply(_ value: Reading, scale: Int) {
        id = value.id
        registerID = value.registerID
        deviceID = value.deviceID
        day = value.day.rawValue
        timeMinutes = value.time?.minuteOfDay
        let stored = ScaledDecimal(value.value, scale: scale)
        scaledValue = stored.scaled
        valueScale = stored.scale
        originID = value.origin.rawValue
        note = value.note
        photoID = value.photoID
        createdAt = value.createdAt
    }
}

// MARK: - Tariff

extension TariffRecord {
    func toDomain() -> Tariff {
        let money = { (raw: Int) in ScaledDecimal(scaled: raw, scale: self.valueScale).value }
        let conversion: GasConversion? = {
            guard let state = gasStateNumberScaled, let calorific = gasCalorificValueScaled else { return nil }
            return GasConversion(stateNumber: money(state), calorificValue: money(calorific))
        }()
        return Tariff(
            id: id,
            meteringPointID: meteringPointID,
            registerID: registerID,
            validFrom: Mapping.day(validFrom),
            validTo: validTo.flatMap { CalendarDay(rawValue: $0) },
            pricePerUnit: money(pricePerUnitScaled),
            monthlyBasePrice: money(monthlyBasePriceScaled),
            currency: CurrencyCode(currencyCode),
            billingUnit: Mapping.unit(billingUnitID),
            gasConversion: conversion,
            feedInPricePerUnit: feedInPriceScaled.map(money)
        )
    }

    func apply(_ value: Tariff) {
        id = value.id
        meteringPointID = value.meteringPointID
        registerID = value.registerID
        validFrom = value.validFrom.rawValue
        validTo = value.validTo?.rawValue
        valueScale = ScaledDecimal.moneyScale
        pricePerUnitScaled = ScaledDecimal(money: value.pricePerUnit).scaled
        monthlyBasePriceScaled = ScaledDecimal(money: value.monthlyBasePrice).scaled
        currencyCode = value.currency.code
        billingUnitID = value.billingUnit.rawValue
        gasStateNumberScaled = value.gasConversion.map { ScaledDecimal(money: $0.stateNumber).scaled }
        gasCalorificValueScaled = value.gasConversion.map { ScaledDecimal(money: $0.calorificValue).scaled }
        feedInPriceScaled = value.feedInPricePerUnit.map { ScaledDecimal(money: $0).scaled }
    }
}

// MARK: - BillingPeriod

extension BillingPeriodRecord {
    func toDomain() -> BillingPeriod? {
        guard let range = DayRange(start: Mapping.day(rangeStart), end: Mapping.day(rangeEnd)) else {
            return nil
        }
        return BillingPeriod(
            id: id,
            meteringPointID: meteringPointID,
            provider: provider,
            customerReference: customerReference,
            range: range,
            monthlyPrepayment: monthlyPrepaymentScaled.map {
                ScaledDecimal(scaled: $0, scale: valueScale).value
            },
            currency: CurrencyCode(currencyCode)
        )
    }

    func apply(_ value: BillingPeriod) {
        id = value.id
        meteringPointID = value.meteringPointID
        provider = value.provider
        customerReference = value.customerReference
        rangeStart = value.range.start.rawValue
        rangeEnd = value.range.end.rawValue
        valueScale = ScaledDecimal.moneyScale
        monthlyPrepaymentScaled = value.monthlyPrepayment.map { ScaledDecimal(money: $0).scaled }
        currencyCode = value.currency.code
    }
}
