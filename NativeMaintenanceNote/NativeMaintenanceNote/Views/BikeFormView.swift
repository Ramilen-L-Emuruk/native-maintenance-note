//
//  BikeFormView.swift
//  NativeMaintenanceNote
//
//  bikeがnilなら新規作成、非nilなら編集モード。
//

import SwiftUI
import SwiftData

struct BikeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Maker.name) private var makers: [Maker]
    @Query(sort: \Shop.name) private var shops: [Shop]

    let bike: Bike?

    @State private var selectedMaker: Maker?
    @State private var selectedShop: Shop?
    @State private var name: String
    @State private var frameNumber: String
    @State private var nickname: String
    @State private var displacementText: String
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var mileageAtRegistrationText: String
    @State private var totalMileageText: String
    @State private var hasInspectionExpiryDate: Bool
    @State private var inspectionExpiryDate: Date
    @State private var memo: String
    @State private var archived: Bool

    @State private var isPresentingAddMaker = false
    @State private var isPresentingAddShop = false
    @State private var isPresentingDeleteConfirmation = false

    init(bike: Bike?) {
        self.bike = bike
        _selectedMaker = State(initialValue: bike?.maker)
        _selectedShop = State(initialValue: bike?.purchaseShop)
        _name = State(initialValue: bike?.name ?? "")
        _frameNumber = State(initialValue: bike?.frameNumber ?? "")
        _nickname = State(initialValue: bike?.nickname ?? "")
        _displacementText = State(initialValue: (bike?.displacement).flatMap { $0 > 0 ? String($0) : nil } ?? "")
        _hasPurchaseDate = State(initialValue: bike?.purchaseDate != nil)
        _purchaseDate = State(initialValue: bike?.purchaseDate ?? Date())
        _mileageAtRegistrationText = State(initialValue: String(bike?.mileageAtRegistration ?? 0))
        _totalMileageText = State(initialValue: String(bike?.totalMileage ?? 0))
        _hasInspectionExpiryDate = State(initialValue: bike?.inspectionExpiryDate != nil)
        _inspectionExpiryDate = State(initialValue: bike?.inspectionExpiryDate ?? Date())
        _memo = State(initialValue: bike?.memo ?? "")
        _archived = State(initialValue: bike?.archived ?? false)
    }

    private var isEditing: Bool { bike != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMaker != nil
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("車種名", text: $name)
                TextField("ニックネーム", text: $nickname)
                TextField("車体番号", text: $frameNumber)

                Picker("メーカー", selection: $selectedMaker) {
                    Text("未選択").tag(nil as Maker?)
                    ForEach(makers) { maker in
                        Text(maker.name).tag(maker as Maker?)
                    }
                }
                Button("メーカーを追加") {
                    isPresentingAddMaker = true
                }

                TextField("排気量(cc)", text: $displacementText)
                    .keyboardType(.numberPad)
            }

            Section("購入情報") {
                Picker("購入店", selection: $selectedShop) {
                    Text("未選択").tag(nil as Shop?)
                    ForEach(shops) { shop in
                        Text(shop.name).tag(shop as Shop?)
                    }
                }
                Button("購入店を追加") {
                    isPresentingAddShop = true
                }

                Toggle("購入日を設定", isOn: $hasPurchaseDate)
                if hasPurchaseDate {
                    DatePicker("購入日", selection: $purchaseDate, displayedComponents: .date)
                }

                TextField("登録時走行距離(km)", text: $mileageAtRegistrationText)
                    .keyboardType(.numberPad)
            }

            Section("現在の状態") {
                TextField("現在の走行距離(km)", text: $totalMileageText)
                    .keyboardType(.numberPad)

                Toggle("車検満了日を設定", isOn: $hasInspectionExpiryDate)
                if hasInspectionExpiryDate {
                    DatePicker("車検満了日", selection: $inspectionExpiryDate, displayedComponents: .date)
                }
            }

            Section("メモ") {
                TextEditor(text: $memo)
                    .frame(minHeight: 80)
            }

            if isEditing {
                Section {
                    Toggle("アーカイブ済み", isOn: $archived)
                }

                Section {
                    Button("このバイクを削除", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "バイクを編集" : "バイクを追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!isValid)
            }
        }
        .sheet(isPresented: $isPresentingAddMaker) {
            AddMakerSheet { newMaker in
                selectedMaker = newMaker
            }
        }
        .sheet(isPresented: $isPresentingAddShop) {
            AddShopSheet { newShop in
                selectedShop = newShop
            }
        }
        .confirmationDialog(
            "このバイクを削除しますか？関連する整備・保険・給油記録もすべて削除されます。",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        let displacement = Int(displacementText) ?? 0
        let mileageAtRegistration = Int(mileageAtRegistrationText) ?? 0
        let totalMileage = Int(totalMileageText) ?? 0

        if let bike {
            bike.maker = selectedMaker
            bike.name = name
            bike.frameNumber = frameNumber
            bike.nickname = nickname
            bike.displacement = displacement
            bike.purchaseShop = selectedShop
            bike.purchaseDate = hasPurchaseDate ? purchaseDate : nil
            bike.mileageAtRegistration = mileageAtRegistration
            bike.totalMileage = totalMileage
            bike.inspectionExpiryDate = hasInspectionExpiryDate ? inspectionExpiryDate : nil
            bike.memo = memo
            bike.archived = archived
        } else {
            let newBike = Bike(
                maker: selectedMaker,
                name: name,
                frameNumber: frameNumber,
                nickname: nickname,
                displacement: displacement,
                purchaseShop: selectedShop,
                purchaseDate: hasPurchaseDate ? purchaseDate : nil,
                mileageAtRegistration: mileageAtRegistration,
                totalMileage: totalMileage,
                inspectionExpiryDate: hasInspectionExpiryDate ? inspectionExpiryDate : nil,
                memo: memo
            )
            modelContext.insert(newBike)
        }
        dismiss()
    }

    private func delete() {
        if let bike {
            modelContext.delete(bike)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BikeFormView(bike: nil)
    }
    .modelContainer(for: [Bike.self, Maker.self, Shop.self], inMemory: true)
}
