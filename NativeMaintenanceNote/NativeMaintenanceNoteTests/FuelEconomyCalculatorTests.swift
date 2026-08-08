//
//  FuelEconomyCalculatorTests.swift
//  NativeMaintenanceNoteTests
//

import Testing
import Foundation
@testable import NativeMaintenanceNote

struct FuelEconomyCalculatorTests {

    private func date(_ daysFromReference: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: TimeInterval(daysFromReference * 86400))
    }

    @Test func distanceClampsNegativeToZero() {
        #expect(FuelEconomyCalculator.distance(previousMileage: 5000, totalMileage: 4800) == 0)
        #expect(FuelEconomyCalculator.distance(previousMileage: 5000, totalMileage: 5300) == 300)
    }

    @Test func economyFallsBackToSingleRecordWhenNoAnchorExists() {
        let record = FuelEconomySample(
            date: date(0),
            previousMileage: 4700,
            totalMileage: 5000,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )

        let economy = FuelEconomyCalculator.economy(for: record, in: [record])

        #expect(economy == 30) // (5000-4700) / 10
    }

    @Test func economySumsFuelBetweenAnchorAndTargetAcrossInterimRecords() {
        let anchor = FuelEconomySample(
            date: date(0),
            previousMileage: 800,
            totalMileage: 1000,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )
        let interim = FuelEconomySample(
            date: date(1),
            previousMileage: 1000,
            totalMileage: 1200,
            price: 750,
            refuelAmount: 5,
            isFullTank: false,
            includeInFuelEconomy: true
        )
        let target = FuelEconomySample(
            date: date(2),
            previousMileage: 1200,
            totalMileage: 1400,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )

        let economy = FuelEconomyCalculator.economy(for: target, in: [anchor, interim, target])

        // (1400 - 1000) / (5 + 10) = 400 / 15
        #expect(abs(economy! - (400.0 / 15.0)) < 0.0001)
    }

    @Test func economyExcludesRecordsWithIncludeInFuelEconomyFalse() {
        let anchor = FuelEconomySample(
            date: date(0),
            previousMileage: 800,
            totalMileage: 1000,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )
        let excludedInterim = FuelEconomySample(
            date: date(1),
            previousMileage: 1000,
            totalMileage: 1200,
            price: 750,
            refuelAmount: 5,
            isFullTank: false,
            includeInFuelEconomy: false
        )
        let target = FuelEconomySample(
            date: date(2),
            previousMileage: 1200,
            totalMileage: 1400,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )

        let economy = FuelEconomyCalculator.economy(for: target, in: [anchor, excludedInterim, target])

        // (1400 - 1000) / 10 = 40 (excludedInterimの給油量は合算しない)
        #expect(economy == 40)
    }

    @Test func economyReturnsNilForNonFullTankRecord() {
        let record = FuelEconomySample(
            date: date(0),
            previousMileage: 800,
            totalMileage: 1000,
            price: 1500,
            refuelAmount: 10,
            isFullTank: false,
            includeInFuelEconomy: true
        )

        #expect(FuelEconomyCalculator.economy(for: record, in: [record]) == nil)
    }

    @Test func averageEconomyAggregatesEligibleRecords() {
        let recordA = FuelEconomySample(
            date: date(0),
            previousMileage: 800,
            totalMileage: 1000,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )
        let excluded = FuelEconomySample(
            date: date(1),
            previousMileage: 1000,
            totalMileage: 1200,
            price: 750,
            refuelAmount: 100,
            isFullTank: false,
            includeInFuelEconomy: false
        )
        let recordB = FuelEconomySample(
            date: date(2),
            previousMileage: 1200,
            totalMileage: 1400,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )

        let average = FuelEconomyCalculator.averageEconomy(records: [recordA, excluded, recordB])

        // 対象はA,Bのみ: 総距離(200+200)/総給油量(10+10) = 20
        #expect(average == 20)
    }

    @Test func chartDataOnlyIncludesFullTankAndEligibleRecordsSortedByDate() {
        let anchor = FuelEconomySample(
            date: date(2),
            previousMileage: 800,
            totalMileage: 1000,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )
        let notFullTank = FuelEconomySample(
            date: date(3),
            previousMileage: 1000,
            totalMileage: 1100,
            price: 500,
            refuelAmount: 3,
            isFullTank: false,
            includeInFuelEconomy: true
        )
        let target = FuelEconomySample(
            date: date(4),
            previousMileage: 1100,
            totalMileage: 1300,
            price: 1500,
            refuelAmount: 10,
            isFullTank: true,
            includeInFuelEconomy: true
        )

        let points = FuelEconomyCalculator.chartData(records: [target, anchor, notFullTank])

        #expect(points.count == 2)
        #expect(points[0].date == anchor.date)
        #expect(points[1].date == target.date)
    }
}
