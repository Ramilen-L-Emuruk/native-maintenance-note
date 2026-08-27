//
//  InsuranceTypeFormView.swift
//  NativeMaintenanceNote
//
//  typeがnilなら新規作成、非nilなら編集モード。
//

import SwiftUI
import SwiftData

struct InsuranceTypeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let type: InsuranceType?

    @State private var name: String
    @State private var notification: Bool
    @State private var isPresentingDeleteConfirmation = false

    init(type: InsuranceType?) {
        self.type = type
        _name = State(initialValue: type?.name ?? "")
        _notification = State(initialValue: type?.notification ?? false)
    }

    private var isEditing: Bool { type != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("保険タイプ") {
                TextField("保険タイプ名", text: $name)
            }

            Section {
                Toggle("通知を有効にする", isOn: $notification)
            }

            if isEditing {
                Section {
                    Button("このタイプを削除", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "保険タイプを編集" : "保険タイプを追加")
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
            "この保険タイプを削除しますか？関連する契約記録もすべて削除されます。",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func save() {
        if let type {
            type.name = name
            type.notification = notification
        } else {
            let newType = InsuranceType(name: name, notification: notification)
            modelContext.insert(newType)
        }
        NotificationScheduler.rescheduleAll(context: modelContext)
        dismiss()
    }

    private func delete() {
        if let type {
            modelContext.delete(type)
        }
        NotificationScheduler.rescheduleAll(context: modelContext)
        dismiss()
    }
}
