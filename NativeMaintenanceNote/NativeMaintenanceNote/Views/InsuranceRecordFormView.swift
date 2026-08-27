//
//  InsuranceRecordFormView.swift
//  NativeMaintenanceNote
//
//  recordがnilなら新規作成、非nilなら編集モード。
//

import SwiftUI
import SwiftData

struct InsuranceRecordFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bike: Bike
    let type: InsuranceType
    let record: InsuranceRecord?

    @State private var name: String
    @State private var priceText: String
    @State private var startDate: Date
    @State private var finishDate: Date
    @State private var url: String
    @State private var memo: String

    @State private var isPresentingDeleteConfirmation = false

    init(bike: Bike, type: InsuranceType, record: InsuranceRecord?) {
        self.bike = bike
        self.type = type
        self.record = record
        _name = State(initialValue: record?.name ?? type.name)
        _priceText = State(initialValue: record.map { String($0.price) } ?? "")
        _startDate = State(initialValue: record?.startDate ?? Date())
        _finishDate = State(initialValue: record?.finishDate ?? Date())
        _url = State(initialValue: record?.url ?? "")
        _memo = State(initialValue: record?.memo ?? "")
    }

    private var isEditing: Bool { record != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("契約内容") {
                TextField("契約名", text: $name)
                TextField("金額(円)", text: $priceText)
                    .keyboardType(.numberPad)
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                DatePicker("満了日", selection: $finishDate, displayedComponents: .date)
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
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
        .navigationTitle(isEditing ? "保険記録を編集" : "保険記録を追加")
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
            "この保険記録を削除しますか？",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        let price = Int(priceText) ?? 0

        if let record {
            record.name = name
            record.price = price
            record.startDate = startDate
            record.finishDate = finishDate
            record.url = url
            record.memo = memo
        } else {
            let newRecord = InsuranceRecord(
                bike: bike,
                type: type,
                name: name,
                price: price,
                startDate: startDate,
                finishDate: finishDate,
                url: url,
                memo: memo
            )
            modelContext.insert(newRecord)
        }
        NotificationScheduler.rescheduleAll(context: modelContext)
        dismiss()
    }

    private func delete() {
        if let record {
            modelContext.delete(record)
        }
        NotificationScheduler.rescheduleAll(context: modelContext)
        dismiss()
    }
}
