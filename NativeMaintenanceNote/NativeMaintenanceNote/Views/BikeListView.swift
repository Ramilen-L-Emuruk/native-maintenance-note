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
    @State private var isPresentingNewBikeForm = false

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
                    isPresentingNewBikeForm = true
                } label: {
                    Label("バイクを追加", systemImage: "plus")
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
        .sheet(isPresented: $isPresentingNewBikeForm) {
            NavigationStack {
                BikeFormView(bike: nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BikeListView(selection: .constant(nil))
    }
    .modelContainer(for: [Bike.self, Maker.self, Shop.self], inMemory: true)
}
