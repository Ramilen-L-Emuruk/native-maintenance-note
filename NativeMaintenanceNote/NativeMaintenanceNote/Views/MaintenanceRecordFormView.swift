//
//  MaintenanceRecordFormView.swift
//  NativeMaintenanceNote
//
//  recordがnilなら新規作成、非nilなら編集モード。
//

import SwiftUI
import SwiftData

struct MaintenanceRecordFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bike: Bike
    let part: MaintenancePart
    let record: MaintenanceRecord?

    @State private var title: String
    @State private var maintenanceDate: Date
    @State private var priceText: String
    @State private var hasMileage: Bool
    @State private var mileageText: String
    @State private var memo: String

    @State private var isPresentingDeleteConfirmation = false

    init(bike: Bike, part: MaintenancePart, record: MaintenanceRecord?) {
        self.bike = bike
        self.part = part
        self.record = record
        _title = State(initialValue: record?.title ?? part.name)
        _maintenanceDate = State(initialValue: record?.maintenanceDate ?? Date())
        _priceText = State(initialValue: record.map { String($0.price) } ?? "")
        _hasMileage = State(initialValue: record?.mileage != nil)
        _mileageText = State(initialValue: record?.mileage.map(String.init) ?? "")
        _memo = State(initialValue: record?.memo ?? "")
    }

    private var isEditing: Bool { record != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("整備内容") {
                TextField("タイトル", text: $title)
                DatePicker("整備日", selection: $maintenanceDate, displayedComponents: .date)
                TextField("金額(円)", text: $priceText)
                    .keyboardType(.numberPad)
            }

            Section("走行距離") {
                Toggle("走行距離を記録", isOn: $hasMileage)
                if hasMileage {
                    TextField("走行距離(km)", text: $mileageText)
                        .keyboardType(.numberPad)
                }
            }

            Section("メモ") {
                TextEditor(text: $memo)
                    .frame(minHeight: 80)
            }

            if isEditing {
                Section {
                    Button("この記録を削除", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "整備記録を編集" : "整備記録を追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!isValid)
            }
        }
        .confirmationDialog(
            "この整備記録を削除しますか？",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        let price = Int(priceText) ?? 0
        let mileage = hasMileage ? Int(mileageText) : nil

        if let record {
            record.title = title
            record.maintenanceDate = maintenanceDate
            record.price = price
            record.mileage = mileage
            record.memo = memo
        } else {
            let newRecord = MaintenanceRecord(
                bike: bike,
                part: part,
                title: title,
                maintenanceDate: maintenanceDate,
                price: price,
                mileage: mileage,
                memo: memo
            )
            modelContext.insert(newRecord)
        }
        dismiss()
    }

    private func delete() {
        if let record {
            modelContext.delete(record)
        }
        dismiss()
    }
}
