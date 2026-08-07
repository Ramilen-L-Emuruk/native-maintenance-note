//
//  BikeListView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct BikeListView: View {
    @Query(sort: \Bike.name) private var allBikes: [Bike]
    @Binding var selection: Bike?

    @State private var showArchived = false
    @State private var activeSheet: ActiveSheet?

    private var visibleBikes: [Bike] {
        allBikes.filter { showArchived || !$0.archived }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(visibleBikes) { bike in
                VStack(alignment: .leading) {
                    Text(bike.name)
                    if !bike.nickname.isEmpty {
                        Text(bike.nickname)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(bike)
            }
        }
        .navigationTitle("バイク")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Toggle("アーカイブ済みを表示", isOn: $showArchived)
                    .toggleStyle(.button)
            }
            ToolbarItem {
                Button {
                    activeSheet = .newBike
                } label: {
                    Label("バイクを追加", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button {
                    activeSheet = .maintenanceTypeManagement
                } label: {
                    Label("整備タイプ管理", systemImage: "wrench.and.screwdriver")
                }
            }
            ToolbarItem {
                Button {
                    activeSheet = .insuranceTypeManagement
                } label: {
                    Label("保険タイプ管理", systemImage: "shield")
                }
            }
            ToolbarItem {
                NavigationLink {
                    LocationVerificationView()
                } label: {
                    Label("GPS検証", systemImage: "location")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newBike:
                NavigationStack {
                    BikeFormView(bike: nil)
                }
            case .maintenanceTypeManagement:
                MaintenanceTypeManagementView()
            case .insuranceTypeManagement:
                InsuranceTypeManagementView()
            }
        }
    }
}

private enum ActiveSheet: Identifiable {
    case newBike
    case maintenanceTypeManagement
    case insuranceTypeManagement

    var id: Self { self }
}

#Preview {
    NavigationStack {
        BikeListView(selection: .constant(nil))
    }
    .modelContainer(for: [Bike.self, Maker.self, Shop.self], inMemory: true)
}
