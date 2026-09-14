//
//  MaintenancePartFormView.swift
//  NativeMaintenanceNote
//
//  partがnilなら新規作成、非nilなら編集モード。
//

import SwiftUI
import SwiftData

struct MaintenancePartFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let type: MaintenanceType
    let part: MaintenancePart?

    @State private var name: String
    @State private var hasIntervalDays: Bool
    @State private var intervalDaysText: String
    @State private var hasIntervalDistance: Bool
    @State private var intervalDistanceText: String
    @State private var notification: Bool

    @State private var isPresentingDeleteConfirmation = false

    init(type: MaintenanceType, part: MaintenancePart?) {
        self.type = type
        self.part = part
        _name = State(initialValue: part?.name ?? "")
        _hasIntervalDays = State(initialValue: part?.intervalDays != nil)
        _intervalDaysText = State(initialValue: part?.intervalDays.map(String.init) ?? "")
        _hasIntervalDistance = State(initialValue: part?.intervalDistance != nil)
        _intervalDistanceText = State(initialValue: part?.intervalDistance.map(String.init) ?? "")
        _notification = State(initialValue: part?.notification ?? false)
    }

    private var isEditing: Bool { part != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("部品") {
                TextField("部品名", text: $name)
            }

            Section("推奨交換間隔") {
                Toggle("日数で管理", isOn: $hasIntervalDays)
                if hasIntervalDays {
                    TextField("日数", text: $intervalDaysText)
                        .keyboardType(.numberPad)
                }
                Toggle("走行距離で管理", isOn: $hasIntervalDistance)
                if hasIntervalDistance {
                    TextField("走行距離(km)", text: $intervalDistanceText)
                        .keyboardType(.numberPad)
                }
            }

            Section {
                Toggle("通知を有効にする", isOn: $notification)
            } footer: {
                Text("日数で管理している部品だけが通知の対象です。走行距離のみで管理している部品は通知されません。通知する時期は設定画面で変更できます。")
            }

            if isEditing {
                Section {
                    Button("この部品を削除", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "部品を編集" : "部品を追加")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!isValid)
            }
        }
        .confirmationDialog(
            "この部品を削除しますか？関連する整備記録もすべて削除されます。",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        let intervalDays = hasIntervalDays ? Int(intervalDaysText) : nil
        let intervalDistance = hasIntervalDistance ? Int(intervalDistanceText) : nil

        if let part {
            part.name = name
            part.intervalDays = intervalDays
            part.intervalDistance = intervalDistance
            part.notification = notification
        } else {
            let newPart = MaintenancePart(
                type: type,
                name: name,
                intervalDays: intervalDays,
                intervalDistance: intervalDistance,
                notification: notification
            )
            modelContext.insert(newPart)
        }
        NotificationScheduler.rescheduleAll(context: modelContext)
        dismiss()
    }

    private func delete() {
        if let part {
            modelContext.delete(part)
        }
        NotificationScheduler.rescheduleAll(context: modelContext)
        dismiss()
    }
}
