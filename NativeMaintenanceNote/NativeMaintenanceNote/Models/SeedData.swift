//
//  SeedData.swift
//  NativeMaintenanceNote
//

import Foundation
import SwiftData

enum SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let makerCount = (try? context.fetchCount(FetchDescriptor<Maker>())) ?? 0
        guard makerCount == 0 else { return }

        seedMakers(context: context)
        seedInsuranceTypes(context: context)
        seedMaintenanceTypes(context: context)
    }

    private static func seedMakers(context: ModelContext) {
        let names = [
            "Honda", "Yamaha", "Suzuki", "Kawasaki", "Harley-Davidson",
            "BMW Motorrad", "Ducati", "Triumph", "KTM", "Aprilia",
            "Moto Guzzi", "Vespa", "Royal Enfield", "Indian", "MV Agusta", "Husqvarna",
        ]
        for name in names {
            context.insert(Maker(name: name, isSeeded: true))
        }
    }

    private static func seedInsuranceTypes(context: ModelContext) {
        let types: [(name: String, notification: Bool)] = [
            ("自賠責保険", true),
            ("任意保険", true),
            ("盗難保険", false),
            ("ロードサービス", false),
        ]
        for type in types {
            context.insert(InsuranceType(name: type.name, notification: type.notification, isSeeded: true))
        }
    }

    private struct PartSeed {
        let name: String
        let intervalDays: Int?
        let intervalDistance: Int?
    }

    private static func seedMaintenanceTypes(context: ModelContext) {
        let typeSeeds: [(name: String, parts: [PartSeed])] = [
            ("エンジン", [
                PartSeed(name: "エンジンオイル", intervalDays: 180, intervalDistance: 3000),
                PartSeed(name: "オイルフィルター", intervalDays: 365, intervalDistance: 6000),
                PartSeed(name: "スパークプラグ", intervalDays: 730, intervalDistance: 8000),
                PartSeed(name: "エアクリーナー", intervalDays: 365, intervalDistance: 10000),
                PartSeed(name: "冷却水(クーラント)", intervalDays: 730, intervalDistance: 20000),
            ]),
            ("タイヤ", [
                PartSeed(name: "フロント", intervalDays: nil, intervalDistance: 15000),
                PartSeed(name: "リア", intervalDays: nil, intervalDistance: 12000),
                PartSeed(name: "空気圧チェック", intervalDays: 30, intervalDistance: nil),
            ]),
            ("ブレーキ", [
                PartSeed(name: "パッド前", intervalDays: nil, intervalDistance: 10000),
                PartSeed(name: "パッド後", intervalDays: nil, intervalDistance: 10000),
                PartSeed(name: "フルード", intervalDays: 730, intervalDistance: nil),
            ]),
            ("駆動系", [
                PartSeed(name: "チェーン給油", intervalDays: 30, intervalDistance: 500),
                PartSeed(name: "チェーン調整", intervalDays: 180, intervalDistance: 3000),
                PartSeed(name: "スプロケット", intervalDays: nil, intervalDistance: 20000),
            ]),
            ("電装系", [
                PartSeed(name: "バッテリー", intervalDays: 730, intervalDistance: nil),
                PartSeed(name: "ヘッドライトバルブ", intervalDays: nil, intervalDistance: nil),
            ]),
            ("車体", [
                PartSeed(name: "洗車", intervalDays: 30, intervalDistance: nil),
                PartSeed(name: "各部給脂", intervalDays: 365, intervalDistance: nil),
            ]),
        ]

        for typeSeed in typeSeeds {
            let type = MaintenanceType(name: typeSeed.name, isSeeded: true)
            context.insert(type)
            for partSeed in typeSeed.parts {
                let part = MaintenancePart(
                    type: type,
                    name: partSeed.name,
                    intervalDays: partSeed.intervalDays,
                    intervalDistance: partSeed.intervalDistance,
                    notification: false,
                    isSeeded: true
                )
                context.insert(part)
            }
        }
    }
}
