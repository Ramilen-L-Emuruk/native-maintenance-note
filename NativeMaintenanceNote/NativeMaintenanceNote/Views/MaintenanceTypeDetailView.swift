//
//  MaintenanceTypeDetailView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct MaintenanceTypeDetailView: View {
    @Bindable var type: MaintenanceType
    @State private var activeSheet: PartSheet?

    private var sortedParts: [MaintenancePart] {
        type.parts.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            ForEach(sortedParts) { part in
                Button {
                    activeSheet = .edit(part)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(part.name)
                            Text(intervalSummary(for: part))
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
                    Label("部品を追加", systemImage: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .new:
                    MaintenancePartFormView(type: type, part: nil)
                case .edit(let part):
                    MaintenancePartFormView(type: type, part: part)
                }
            }
        }
    }

    private func intervalSummary(for part: MaintenancePart) -> String {
        var components: [String] = []
        if let days = part.intervalDays {
            components.append("\(days)日")
        }
        if let distance = part.intervalDistance {
            components.append("\(distance)km")
        }
        return components.isEmpty ? "間隔未設定" : components.joined(separator: " / ")
    }
}

private enum PartSheet: Identifiable {
    case new
    case edit(MaintenancePart)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let part): return part.id.uuidString
        }
    }
}
