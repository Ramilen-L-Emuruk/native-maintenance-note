//
//  MaintenanceRecordListView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct MaintenanceRecordListView: View {
    let bike: Bike
    let part: MaintenancePart
    @Query private var records: [MaintenanceRecord]

    @State private var activeSheet: RecordSheet?

    private static let dateFormat = Date.FormatStyle(date: .numeric)

    init(bike: Bike, part: MaintenancePart) {
        self.bike = bike
        self.part = part
        let bikeID = bike.persistentModelID
        let partID = part.persistentModelID
        _records = Query(
            filter: #Predicate<MaintenanceRecord> { record in
                record.bike?.persistentModelID == bikeID && record.part?.persistentModelID == partID
            },
            sort: \MaintenanceRecord.maintenanceDate,
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
                            Text(record.title)
                            HStack {
                                Text(record.maintenanceDate.formatted(Self.dateFormat))
                                if let mileage = record.mileage {
                                    Text("\(mileage)km")
                                }
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
        .navigationTitle(part.name)
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
                    MaintenanceRecordFormView(bike: bike, part: part, record: nil)
                case .edit(let record):
                    MaintenanceRecordFormView(bike: bike, part: part, record: record)
                }
            }
        }
    }
}

private enum RecordSheet: Identifiable {
    case new
    case edit(MaintenanceRecord)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let record): return record.id.uuidString
        }
    }
}
