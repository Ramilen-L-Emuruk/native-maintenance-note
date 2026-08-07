//
//  InsuranceRecordListView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct InsuranceRecordListView: View {
    let bike: Bike
    let type: InsuranceType
    @Query private var records: [InsuranceRecord]

    @State private var activeSheet: RecordSheet?

    private static let dateFormat = Date.FormatStyle(date: .numeric)

    init(bike: Bike, type: InsuranceType) {
        self.bike = bike
        self.type = type
        let bikeID = bike.persistentModelID
        let typeID = type.persistentModelID
        _records = Query(
            filter: #Predicate<InsuranceRecord> { record in
                record.bike?.persistentModelID == bikeID && record.type?.persistentModelID == typeID
            },
            sort: \InsuranceRecord.finishDate,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(records) { record in
                Button {
                    activeSheet = .edit(record)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.name)
                            HStack {
                                Text("\(record.startDate.formatted(Self.dateFormat))〜\(record.finishDate.formatted(Self.dateFormat))")
                                Text("¥\(record.price)")
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
        .navigationTitle(type.name)
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
                    InsuranceRecordFormView(bike: bike, type: type, record: nil)
                case .edit(let record):
                    InsuranceRecordFormView(bike: bike, type: type, record: record)
                }
            }
        }
    }
}

private enum RecordSheet: Identifiable {
    case new
    case edit(InsuranceRecord)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let record): return record.id.uuidString
        }
    }
}
