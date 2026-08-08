//
//  FuelEconomyCalculator.swift
//  NativeMaintenanceNote
//
//  満タン法(満タン給油の間隔で距離÷給油量を算出する、日本で標準的な
//  燃費計算方式)。SwiftDataに依存しない素のSwift実装にして、
//  ModelContainerなしでユニットテストできるようにしている。
//

import Foundation

struct FuelEconomySample: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let previousMileage: Int
    let totalMileage: Int
    let price: Int
    let refuelAmount: Double
    let isFullTank: Bool
    let includeInFuelEconomy: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        previousMileage: Int,
        totalMileage: Int,
        price: Int,
        refuelAmount: Double,
        isFullTank: Bool,
        includeInFuelEconomy: Bool
    ) {
        self.id = id
        self.date = date
        self.previousMileage = previousMileage
        self.totalMileage = totalMileage
        self.price = price
        self.refuelAmount = refuelAmount
        self.isFullTank = isFullTank
        self.includeInFuelEconomy = includeInFuelEconomy
    }
}

enum FuelEconomyCalculator {
    struct ChartPoint {
        let date: Date
        let economy: Double
        let pricePerLiter: Double
    }

    /// 前回給油からの走行距離。オドメーターの巻き戻り等で負値になる場合は0にクランプする。
    static func distance(previousMileage: Int, totalMileage: Int) -> Int {
        max(0, totalMileage - previousMileage)
    }

    /// 満タン法による燃費(km/L)。満タン記録以外はnilを返す。
    static func economy(for target: FuelEconomySample, in allRecords: [FuelEconomySample]) -> Double? {
        guard target.isFullTank else { return nil }

        let sorted = allRecords.sorted(by: sortByMileageThenDate)
        guard let targetIndex = sorted.firstIndex(where: { $0.id == target.id }) else { return nil }

        let precedingFullTankIndex = sorted[..<targetIndex].lastIndex { $0.isFullTank }

        guard let anchorIndex = precedingFullTankIndex else {
            // 直前の満タン記録がない場合は、この1件だけでの距離/給油量にフォールバックする。
            guard target.refuelAmount > 0 else { return nil }
            let dist = distance(previousMileage: target.previousMileage, totalMileage: target.totalMileage)
            return Double(dist) / target.refuelAmount
        }

        let anchor = sorted[anchorIndex]
        let between = sorted[(anchorIndex + 1)...targetIndex].filter { $0.includeInFuelEconomy }
        let totalFuel = between.reduce(0.0) { $0 + $1.refuelAmount }
        guard totalFuel > 0 else { return nil }

        let dist = max(0, target.totalMileage - anchor.totalMileage)
        return Double(dist) / totalFuel
    }

    /// 対象期間全体の平均燃費(km/L)。includeInFuelEconomy=trueの記録のみを集計する。
    static func averageEconomy(records: [FuelEconomySample]) -> Double? {
        let eligible = records.filter { $0.includeInFuelEconomy }
        guard !eligible.isEmpty else { return nil }

        let totalDistance = eligible.reduce(0) { $0 + distance(previousMileage: $1.previousMileage, totalMileage: $1.totalMileage) }
        let totalFuel = eligible.reduce(0.0) { $0 + $1.refuelAmount }
        guard totalFuel > 0 else { return nil }

        return Double(totalDistance) / totalFuel
    }

    /// グラフ用データ。満タン法で燃費が算出できる記録のみ、日付昇順で返す。
    static func chartData(records: [FuelEconomySample]) -> [ChartPoint] {
        records
            .filter { $0.includeInFuelEconomy && $0.isFullTank }
            .sorted { $0.date < $1.date }
            .compactMap { record in
                guard let eco = economy(for: record, in: records) else { return nil }
                let pricePerLiter = record.refuelAmount > 0 ? Double(record.price) / record.refuelAmount : 0
                return ChartPoint(date: record.date, economy: eco, pricePerLiter: pricePerLiter)
            }
    }

    private static func sortByMileageThenDate(_ lhs: FuelEconomySample, _ rhs: FuelEconomySample) -> Bool {
        if lhs.totalMileage != rhs.totalMileage {
            return lhs.totalMileage < rhs.totalMileage
        }
        return lhs.date < rhs.date
    }
}
