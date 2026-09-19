//
//  BackupImporter.swift
//  NativeMaintenanceNote
//
//  Web版バックアップJSON(BackupDTO)をSwiftDataモデルへ取り込む。
//  マスタデータ(Maker/Shop/MaintenanceType/MaintenancePart/InsuranceType)は
//  名前一致で既存レコードに合流させ、一致しなければ新規作成する。
//  Bike以下(Bike/MaintenanceRecord/InsuranceRecord/RefuelRecord)は常に新規作成するため、
//  同じファイルを再インポートすると重複する(冪等ではない)。
//

import Foundation
import SwiftData

enum BackupImportError: Error, LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "このファイルはメンテナンスノートのバックアップではないようです。"
        }
    }
}

struct ImportPreview {
    let bikeCount: Int
    let maintenanceRecordCount: Int
    let insuranceRecordCount: Int
    let refuelRecordCount: Int
    let newMakerNames: [String]
    let newShopNames: [String]
    let newMaintenanceTypeNames: [String]
    let newMaintenancePartNames: [String]
    let newInsuranceTypeNames: [String]
}

struct ImportSummary {
    let bikeCount: Int
    let maintenanceRecordCount: Int
    let insuranceRecordCount: Int
    let refuelRecordCount: Int
}

enum BackupImporter {
    static func decode(_ data: Data) throws -> BackupDTO {
        let dto: BackupDTO
        do {
            dto = try JSONDecoder().decode(BackupDTO.self, from: data)
        } catch {
            throw BackupImportError.invalidFormat
        }
        guard dto.app == "web-maintenance-note" else {
            throw BackupImportError.invalidFormat
        }
        return dto
    }

    static func preview(_ dto: BackupDTO, context: ModelContext) -> ImportPreview {
        let existingMakerNames = Set((fetchAll(Maker.self, context: context)).map(\.name))
        let existingShopNames = Set((fetchAll(Shop.self, context: context)).map(\.name))
        let existingTypeNames = Set((fetchAll(MaintenanceType.self, context: context)).map(\.name))
        let existingInsuranceTypeNames = Set((fetchAll(InsuranceType.self, context: context)).map(\.name))
        let existingPartKeys = Set(fetchAll(MaintenancePart.self, context: context).compactMap { part -> String? in
            guard let typeName = part.type?.name else { return nil }
            return partKey(typeName: typeName, partName: part.name)
        })

        let dtoTypeNameById = Dictionary(uniqueKeysWithValues: dto.maintenanceTypes.map { ($0.id, $0.name) })
        let newPartKeys = dto.maintenanceParts.compactMap { part -> String? in
            guard let typeName = dtoTypeNameById[part.maintenanceTypeId] else { return nil }
            let key = partKey(typeName: typeName, partName: part.name)
            return existingPartKeys.contains(key) ? nil : key
        }

        return ImportPreview(
            bikeCount: dto.bikes.count,
            maintenanceRecordCount: dto.maintenanceRecords.count,
            insuranceRecordCount: dto.insuranceRecords.count,
            refuelRecordCount: dto.refuelRecords.count,
            newMakerNames: Array(Set(dto.makers.map(\.name)).subtracting(existingMakerNames)).sorted(),
            newShopNames: Array(Set(dto.shops.map(\.name)).subtracting(existingShopNames)).sorted(),
            newMaintenanceTypeNames: Array(Set(dto.maintenanceTypes.map(\.name)).subtracting(existingTypeNames)).sorted(),
            newMaintenancePartNames: Array(Set(newPartKeys)).sorted(),
            newInsuranceTypeNames: Array(Set(dto.insuranceTypes.map(\.name)).subtracting(existingInsuranceTypeNames)).sorted()
        )
    }

    @discardableResult
    static func execute(_ dto: BackupDTO, context: ModelContext) -> ImportSummary {
        let makerByWebID = resolveMasters(
            dtoItems: dto.makers,
            existing: fetchAll(Maker.self, context: context),
            existingKey: { $0.name },
            dtoKey: { $0.name },
            makeNew: { Maker(name: $0.name, isSeeded: false) },
            context: context
        )

        let shopByWebID = resolveMasters(
            dtoItems: dto.shops,
            existing: fetchAll(Shop.self, context: context),
            existingKey: { $0.name },
            dtoKey: { $0.name },
            makeNew: { Shop(name: $0.name, address: $0.address, isSeeded: false) },
            context: context
        )

        let typeByWebID = resolveMasters(
            dtoItems: dto.maintenanceTypes,
            existing: fetchAll(MaintenanceType.self, context: context),
            existingKey: { $0.name },
            dtoKey: { $0.name },
            makeNew: { MaintenanceType(name: $0.name, isSeeded: false) },
            context: context
        )

        let insuranceTypeByWebID = resolveMasters(
            dtoItems: dto.insuranceTypes,
            existing: fetchAll(InsuranceType.self, context: context),
            existingKey: { $0.name },
            dtoKey: { $0.name },
            makeNew: { InsuranceType(name: $0.name, notification: $0.notification, isSeeded: false) },
            context: context
        )

        var partByWebID: [String: MaintenancePart] = [:]
        var partByKey: [String: MaintenancePart] = [:]
        for part in fetchAll(MaintenancePart.self, context: context) {
            guard let typeName = part.type?.name else { continue }
            partByKey[partKey(typeName: typeName, partName: part.name)] = part
        }
        for partDTO in dto.maintenanceParts {
            guard let type = typeByWebID[partDTO.maintenanceTypeId] else { continue }
            let key = partKey(typeName: type.name, partName: partDTO.name)
            if let existing = partByKey[key] {
                partByWebID[partDTO.id] = existing
            } else {
                let newPart = MaintenancePart(
                    type: type,
                    name: partDTO.name,
                    intervalDays: partDTO.intervalDays,
                    intervalDistance: partDTO.intervalDistance,
                    notification: partDTO.notification,
                    isSeeded: false
                )
                context.insert(newPart)
                partByKey[key] = newPart
                partByWebID[partDTO.id] = newPart
            }
        }

        var bikeByWebID: [String: Bike] = [:]
        for bikeDTO in dto.bikes {
            let newBike = Bike(
                maker: makerByWebID[bikeDTO.makerId],
                name: bikeDTO.name,
                frameNumber: bikeDTO.frameNumber,
                nickname: bikeDTO.nickname,
                displacement: bikeDTO.displacement,
                purchaseShop: bikeDTO.purchaseShopId.flatMap { shopByWebID[$0] },
                purchaseDate: bikeDTO.purchaseDate.flatMap(parseDate),
                mileageAtRegistration: bikeDTO.mileageAtRegistration,
                totalMileage: bikeDTO.totalMileage,
                imageFilenames: importImages(bikeDTO.images),
                inspectionExpiryDate: bikeDTO.inspectionExpiryDate.flatMap(parseDate),
                memo: bikeDTO.memo,
                archived: bikeDTO.archived
            )
            context.insert(newBike)
            bikeByWebID[bikeDTO.id] = newBike
        }

        for recordDTO in dto.maintenanceRecords {
            guard let bike = bikeByWebID[recordDTO.bikeId],
                  let part = partByWebID[recordDTO.maintenancePartId],
                  let date = parseDate(recordDTO.maintenanceDate) else { continue }
            let record = MaintenanceRecord(
                bike: bike,
                part: part,
                title: recordDTO.title,
                maintenanceDate: date,
                price: recordDTO.price,
                mileage: recordDTO.mileage,
                imageFilenames: importImages(recordDTO.images),
                memo: recordDTO.memo
            )
            context.insert(record)
        }

        for recordDTO in dto.insuranceRecords {
            guard let bike = bikeByWebID[recordDTO.bikeId],
                  let type = insuranceTypeByWebID[recordDTO.insuranceTypeId],
                  let startDate = parseDate(recordDTO.startDate),
                  let finishDate = parseDate(recordDTO.finishDate) else { continue }
            let record = InsuranceRecord(
                bike: bike,
                type: type,
                name: recordDTO.name,
                price: recordDTO.price,
                startDate: startDate,
                finishDate: finishDate,
                url: recordDTO.url,
                imageFilenames: importImages(recordDTO.images),
                memo: recordDTO.memo
            )
            context.insert(record)
        }

        for recordDTO in dto.refuelRecords {
            guard let bike = bikeByWebID[recordDTO.bikeId],
                  let date = combinedDate(dateString: recordDTO.refuelDate, timeString: recordDTO.refuelTime ?? "10:00") else { continue }
            let record = RefuelRecord(
                bike: bike,
                refuelDate: date,
                previousMileage: recordDTO.previousMileage,
                totalMileage: recordDTO.totalMileage,
                price: recordDTO.price,
                refuelAmount: recordDTO.refuelAmount,
                memo: recordDTO.memo,
                isFullTank: recordDTO.isFullTank,
                includeInFuelEconomy: recordDTO.includeInFuelEconomy
            )
            context.insert(record)
        }

        return ImportSummary(
            bikeCount: dto.bikes.count,
            maintenanceRecordCount: dto.maintenanceRecords.count,
            insuranceRecordCount: dto.insuranceRecords.count,
            refuelRecordCount: dto.refuelRecords.count
        )
    }

    // MARK: - マスタデータの名前一致解決

    private static func resolveMasters<DTOItem, Model: PersistentModel>(
        dtoItems: [DTOItem],
        existing: [Model],
        existingKey: (Model) -> String,
        dtoKey: (DTOItem) -> String,
        makeNew: (DTOItem) -> Model,
        context: ModelContext
    ) -> [String: Model] where DTOItem: HasWebID {
        var byName = Dictionary(uniqueKeysWithValues: existing.map { (existingKey($0), $0) })
        var byWebID: [String: Model] = [:]
        for item in dtoItems {
            let name = dtoKey(item)
            if let match = byName[name] {
                byWebID[item.webID] = match
            } else {
                let newModel = makeNew(item)
                context.insert(newModel)
                byName[name] = newModel
                byWebID[item.webID] = newModel
            }
        }
        return byWebID
    }

    private static func partKey(typeName: String, partName: String) -> String {
        "\(typeName)/\(partName)"
    }

    private static func fetchAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    // MARK: - 画像

    private static func importImages(_ dataURLs: [String]) -> [String] {
        dataURLs.compactMap { dataURL in
            guard let data = decodeDataURL(dataURL) else { return nil }
            return try? ImageStore.save(data, filenameExtension: "jpg")
        }
    }

    private static func decodeDataURL(_ string: String) -> Data? {
        guard let commaIndex = string.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(string[string.index(after: commaIndex)...]))
    }

    // MARK: - 日付

    /// DateFormatterはSendableではないため、共有インスタンスを持たず呼び出しごとに作る。
    /// インポートは利用者が明示的に実行する一度きりの操作なので、生成コストより扱いの安全さを取る。
    nonisolated private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }

    nonisolated static func parseDate(_ string: String) -> Date? {
        makeFormatter("yyyy-MM-dd").date(from: string)
    }

    nonisolated static func combinedDate(dateString: String, timeString: String) -> Date? {
        guard let day = parseDate(dateString), let time = makeFormatter("HH:mm").date(from: timeString) else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components)
    }
}

private protocol HasWebID {
    var webID: String { get }
}

extension MakerDTO: HasWebID { var webID: String { id } }
extension ShopDTO: HasWebID { var webID: String { id } }
extension MaintenanceTypeDTO: HasWebID { var webID: String { id } }
extension InsuranceTypeDTO: HasWebID { var webID: String { id } }
