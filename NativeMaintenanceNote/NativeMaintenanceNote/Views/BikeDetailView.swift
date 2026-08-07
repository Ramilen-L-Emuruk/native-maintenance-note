//
//  BikeDetailView.swift
//  NativeMaintenanceNote
//

import SwiftUI
import SwiftData

struct BikeDetailView: View {
    @Bindable var bike: Bike
    @State private var isPresentingEditForm = false

    private static let dateFormat = Date.FormatStyle(date: .numeric)

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("メーカー", value: bike.maker?.name ?? "未設定")
                if !bike.nickname.isEmpty {
                    LabeledContent("ニックネーム", value: bike.nickname)
                }
                if bike.displacement > 0 {
                    LabeledContent("排気量", value: "\(bike.displacement)cc")
                }
                LabeledContent("現在の走行距離", value: "\(bike.totalMileage)km")
            }

            Section("主要日付") {
                if let purchaseDate = bike.purchaseDate {
                    LabeledContent("購入日", value: purchaseDate.formatted(Self.dateFormat))
                }
                if let inspectionExpiryDate = bike.inspectionExpiryDate {
                    LabeledContent("車検満了日", value: inspectionExpiryDate.formatted(Self.dateFormat))
                }
            }

            Section("整備") {
                Text("Phase 2で実装予定")
                    .foregroundStyle(.secondary)
            }

            Section("保険") {
                Text("Phase 3で実装予定")
                    .foregroundStyle(.secondary)
            }

            Section("給油") {
                Text("Phase 4で実装予定")
                    .foregroundStyle(.secondary)
            }

            if !bike.memo.isEmpty {
                Section("メモ") {
                    Text(bike.memo)
                }
            }
        }
        .navigationTitle(bike.name)
        .toolbar {
            ToolbarItem {
                Button("編集") {
                    isPresentingEditForm = true
                }
            }
        }
        .sheet(isPresented: $isPresentingEditForm) {
            NavigationStack {
                BikeFormView(bike: bike)
            }
        }
    }
}
