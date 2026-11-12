#if canImport(CoreData)
import CoreData
import SwiftData

extension PulseStore {

    /// Das CloudKit-Schema, das Core Data für dieses Datenmodell erwartet,
    /// in Apples Schemasprache (CKDB) für `cktool import-schema`.
    ///
    /// **Warum es das gibt.** Die Produktionsumgebung von CloudKit kennt nur
    /// Datensatztypen, die vorher in der Entwicklungsumgebung standen und
    /// übertragen wurden (0.141.0). Dorthin kommen sie entweder über einen
    /// Entwicklungsbau mit angemeldeter iCloud oder über `cktool` mit einem
    /// Verwaltungsschlüssel. Der zweite Weg geht ohne Mac am Schreibtisch, aus
    /// der CI (`.github/workflows/cloudkit-schema.yml`).
    ///
    /// **Abgeleitet, nicht abgeschrieben.** Der Text entsteht aus demselben
    /// `NSManagedObjectModel`, das SwiftData für den Abgleich baut. Die Datei
    /// `cloudkit/schema.ckdb` muss ihm gleichen; `CloudKitSchemaTests` hält
    /// beide zusammen. Ein neues Feld im Modell ohne neue Datei fällt dort auf,
    /// und nicht erst im Laden, wo CloudKit das Hochladen still ablehnt.
    ///
    /// Die Regeln, nach denen `NSPersistentCloudKitContainer` abbildet:
    /// Typ `CD_<Entität>`, Feld `CD_<Eigenschaft>`, dazu `CD_entityName`;
    /// eine Beziehung zu einem einzelnen Objekt als Zeichenkette mit dessen
    /// Kennung; Beziehungen zu vielen stehen nur auf der anderen Seite; Daten
    /// als `BYTES` plus `_ckAsset`, wenn sie zu groß für einen Datensatz sind.
    public static func cloudKitSchemaText() throws -> String {
        guard let modell = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else {
            throw StoreError.containerUnavailable(underlying: CocoaError(.featureUnsupported))
        }
        let suchbar = "STRING QUERYABLE SEARCHABLE SORTABLE"
        let zahl = "INT64 QUERYABLE SORTABLE"
        let system = [
            "\"___createTime\" TIMESTAMP",
            "\"___createdBy\" REFERENCE",
            "\"___etag\" STRING",
            "\"___modTime\" TIMESTAMP",
            "\"___modifiedBy\" REFERENCE",
            "\"___recordID\" REFERENCE"
        ]

        var zeilen = ["DEFINE SCHEMA", ""]
        for entitaet in modell.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            guard let name = entitaet.name else { continue }
            var felder: [String: String] = ["CD_entityName": suchbar]
            for (feld, attribut) in entitaet.attributesByName {
                switch attribut.attributeType {
                case .stringAttributeType, .UUIDAttributeType, .URIAttributeType:
                    felder["CD_\(feld)"] = suchbar
                case .integer16AttributeType, .integer32AttributeType,
                     .integer64AttributeType, .booleanAttributeType:
                    felder["CD_\(feld)"] = zahl
                case .doubleAttributeType, .floatAttributeType:
                    felder["CD_\(feld)"] = "DOUBLE QUERYABLE SORTABLE"
                case .dateAttributeType:
                    felder["CD_\(feld)"] = "TIMESTAMP QUERYABLE SORTABLE"
                case .binaryDataAttributeType:
                    felder["CD_\(feld)"] = "BYTES"
                    felder["CD_\(feld)_ckAsset"] = "ASSET"
                default:
                    throw StoreError.containerUnavailable(
                        underlying: CocoaError(.featureUnsupported,
                                               userInfo: [NSDebugDescriptionErrorKey: "\(name).\(feld)"]))
                }
            }
            for (feld, beziehung) in entitaet.relationshipsByName where !beziehung.isToMany {
                felder["CD_\(feld)"] = suchbar
            }
            zeilen.append("    RECORD TYPE CD_\(name) (")
            for feld in felder.keys.sorted() {
                zeilen.append("        \(feld) \(felder[feld]!),")
            }
            zeilen += system.map { "        \($0)," }
            zeilen += [
                "        GRANT WRITE TO \"_creator\",",
                "        GRANT CREATE TO \"_icloud\",",
                "        GRANT READ TO \"_world\"",
                "    );",
                ""
            ]
        }
        // Den Typ legt Apple selbst an. Ein Import ohne ihn würde ihn entfernen.
        zeilen.append("    RECORD TYPE Users (")
        zeilen += system.map { "        \($0)," }
        zeilen += [
            "        roles LIST<INT64>,",
            "        GRANT WRITE TO \"_creator\",",
            "        GRANT READ TO \"_world\"",
            "    );"
        ]
        return zeilen.joined(separator: "\n") + "\n"
    }

    /// Was am Modell gegen die Regeln von CloudKit verstößt — leer, wenn nichts.
    ///
    /// **Warum es das gibt.** Die drei Regeln stehen seit jeher oben in
    /// `Records.swift`, aber nur als Kommentar. Bricht ein neues Feld eine
    /// davon, merkt es niemand in der CI: Dort läuft der Speicher ohne iCloud.
    /// Auf dem Gerät öffnet SwiftData den Speicher dann ohne Abgleich oder gar
    /// nicht, und der Nutzer sieht nur, dass das iPad leer bleibt — genau das
    /// Bild, das der Abgleich von 1.0 bis 1.6 abgegeben hat (0.149.0).
    ///
    /// Die Regeln sind die von `NSPersistentCloudKitContainer`:
    /// 1. Jede Eigenschaft ist optional oder hat einen Vorgabewert.
    /// 2. Keine Eindeutigkeit über den Speicher (`@Attribute(.unique)`).
    /// 3. Jede Beziehung ist optional, hat eine Umkehrung und löscht nicht
    ///    mit „verweigern“.
    public static func cloudKitRegelVerstoesse(in modell: NSManagedObjectModel) -> [String] {
        var verstoesse: [String] = []
        for entitaet in modell.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            let name = entitaet.name ?? "?"
            if !entitaet.uniquenessConstraints.isEmpty {
                verstoesse.append("\(name): eindeutige Felder (@Attribute(.unique)) kennt CloudKit nicht")
            }
            for (feld, attribut) in entitaet.attributesByName.sorted(by: { $0.key < $1.key })
            where !attribut.isOptional && attribut.defaultValue == nil {
                verstoesse.append("\(name).\(feld): weder optional noch mit Vorgabewert")
            }
            for (feld, beziehung) in entitaet.relationshipsByName.sorted(by: { $0.key < $1.key }) {
                if !beziehung.isOptional {
                    verstoesse.append("\(name).\(feld): Beziehung muss optional sein")
                }
                if beziehung.inverseRelationship == nil {
                    verstoesse.append("\(name).\(feld): Beziehung ohne Umkehrung")
                }
                if beziehung.deleteRule == .denyDeleteRule {
                    verstoesse.append("\(name).\(feld): Löschregel „verweigern“ kennt CloudKit nicht")
                }
            }
        }
        return verstoesse
    }

    /// Das Modell, so wie SwiftData es für den Abgleich baut.
    public static func cloudKitModell() throws -> NSManagedObjectModel {
        guard let modell = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else {
            throw StoreError.containerUnavailable(underlying: CocoaError(.featureUnsupported))
        }
        return modell
    }
}
#endif
