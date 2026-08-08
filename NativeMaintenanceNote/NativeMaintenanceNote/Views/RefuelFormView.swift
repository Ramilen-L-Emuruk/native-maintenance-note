//
//  RefuelFormView.swift
//  NativeMaintenanceNote
//
//  recordがnilなら新規作成、非nilなら編集モード。
//

import SwiftUI
import SwiftData

struct RefuelFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bike: Bike
    let record: RefuelRecord?

    @State private var refuelDate: Date
    @State private var previousMileageText: String
    @State private var totalMileageText: String
    @State private var priceText: String
    @State private var refuelAmountText: String
    @State private var isFullTank: Bool
    @State private var includeInFuelEconomy: Bool
    @State private var memo: String

    @State private var isPresentingDeleteConfirmation = false

    init(bike: Bike, record: RefuelRecord?) {
        self.bike = bike
        self.record = record
        _refuelDate = State(initialValue: record?.refuelDate ?? Date())
        _previousMileageText = State(initialValue: record.map { String($0.previousMileage) } ?? String(bike.totalMileage))
        _totalMileageText = State(initialValue: record.map { String($0.totalMileage) } ?? String(bike.totalMileage))
        _priceText = State(initialValue: record.map { String($0.price) } ?? "")
        _refuelAmountText = State(initialValue: record.map { String($0.refuelAmount) } ?? "")
        _isFullTank = State(initialValue: record?.isFullTank ?? true)
        _includeInFuelEconomy = State(initialValue: record?.includeInFuelEconomy ?? true)
        _memo = State(initialValue: record?.memo ?? "")
    }

    private var isEditing: Bool { record != nil }

    private var isValid: Bool {
        Int(previousMileageText) != nil && Int(totalMileageText) != nil && Double(refuelAmountText) != nil
    }

    var body: some View {
        Form {
            Section("給油日時") {
                DatePicker("給油日時", selection: $refuelDate)
            }

            Section("走行距離") {
                TextField("前回給油時の走行距離(km)", text: $previousMileageText)
                    .keyboardType(.numberPad)
                TextField("今回の走行距離(km)", text: $totalMileageText)
                    .keyboardType(.numberPad)
            }

            Section("給油内容") {
                TextField("給油量(L)", text: $refuelAmountText)
                    .keyboardType(.decimalPad)
                TextField("金額(円)", text: $priceText)
                    .keyboardType(.numberPad)
            }

            Section {
                Toggle("満タン給油", isOn: $isFullTank)
                Toggle("燃費計算に含める", isOn: $includeInFuelEconomy)
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
        .navigationTitle(isEditing ? "給油記録を編集" : "給油記録を追加")
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
            "この給油記録を削除しますか？",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        let previousMileage = Int(previousMileageText) ?? 0
        let totalMileage = Int(totalMileageText) ?? 0
        let price = Int(priceText) ?? 0
        let refuelAmount = Double(refuelAmountText) ?? 0

        if let record {
            record.refuelDate = refuelDate
            record.previousMileage = previousMileage
            record.totalMileage = totalMileage
            record.price = price
            record.refuelAmount = refuelAmount
            record.isFullTank = isFullTank
            record.includeInFuelEconomy = includeInFuelEconomy
            record.memo = memo
        } else {
            let newRecord = RefuelRecord(
                bike: bike,
                refuelDate: refuelDate,
                previousMileage: previousMileage,
                totalMileage: totalMileage,
                price: price,
                refuelAmount: refuelAmount,
                memo: memo,
                isFullTank: isFullTank,
                includeInFuelEconomy: includeInFuelEconomy
            )
            modelContext.insert(newRecord)
        }

        if totalMileage > bike.totalMileage {
            bike.totalMileage = totalMileage
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
