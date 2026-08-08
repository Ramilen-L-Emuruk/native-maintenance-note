//
//  RefuelListView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct RefuelListView: View {
    let bike: Bike
    @Query private var records: [RefuelRecord]

    @State private var activeSheet: RecordSheet?

    private static let dateFormat = Date.FormatStyle(date: .numeric, time: .shortened)

    init(bike: Bike) {
        self.bike = bike
        let bikeID = bike.persistentModelID
        _records = Query(
            filter: #Predicate<RefuelRecord> { record in
                record.bike?.persistentModelID == bikeID
            },
            sort: \RefuelRecord.refuelDate,
            order: .reverse
        )
    }

    private var samples: [FuelEconomySample] {
        records.map {
            FuelEconomySample(
                id: $0.id,
                date: $0.refuelDate,
                previousMileage: $0.previousMileage,
                totalMileage: $0.totalMileage,
                price: $0.price,
                refuelAmount: $0.refuelAmount,
                isFullTank: $0.isFullTank,
                includeInFuelEconomy: $0.includeInFuelEconomy
            )
        }
    }

    private var chartPoints: [FuelEconomyCalculator.ChartPoint] {
        FuelEconomyCalculator.chartData(records: samples)
    }

    private var overallAverage: Double? {
        FuelEconomyCalculator.averageEconomy(records: samples)
    }

    private var thisMonthAverage: Double? {
        let calendar = Calendar.current
        let now = Date()
        let thisMonthSamples = samples.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        return FuelEconomyCalculator.averageEconomy(records: thisMonthSamples)
    }

    var body: some View {
        List {
            Section("燃費統計") {
                LabeledContent("今月の平均燃費", value: formatted(thisMonthAverage))
                LabeledContent("全体の平均燃費", value: formatted(overallAverage))
            }

            if chartPoints.count >= 2 {
                Section("燃費推移") {
                    FuelEconomyChartView(points: chartPoints)
                }
            }

            Section("給油履歴") {
                ForEach(records) { record in
                    Button {
                        activeSheet = .edit(record)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.refuelDate.formatted(Self.dateFormat))
                                HStack {
                                    Text("\(record.totalMileage)km")
                                    Text("\(record.refuelAmount, specifier: "%.2f")L")
                                    Text("¥\(record.price)")
                                    if record.isFullTank {
                                        Text("満タン")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("給油")
        .toolbar {
            ToolbarItem {
                Button {
                    activeSheet = .new
                } label: {
                    Label("記録を追加", systemImage: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .new:
                    RefuelFormView(bike: bike, record: nil)
                case .edit(let record):
                    RefuelFormView(bike: bike, record: record)
                }
            }
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "記録なし" }
        return String(format: "%.2f km/L", value)
    }
}

private enum RecordSheet: Identifiable {
    case new
    case edit(RefuelRecord)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let record): return record.id.uuidString
        }
    }
}
