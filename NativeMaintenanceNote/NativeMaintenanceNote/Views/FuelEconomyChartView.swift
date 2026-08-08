//
//  FuelEconomyChartView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import Charts

struct FuelEconomyChartView: View {
    let points: [FuelEconomyCalculator.ChartPoint]

    var body: some View {
        Chart(points, id: \.date) { point in
            LineMark(
                x: .value("日付", point.date),
                y: .value("燃費(km/L)", point.economy)
            )
            .symbol(.circle)
        }
        .frame(height: 200)
        .chartYAxisLabel("km/L")
    }
}
