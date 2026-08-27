//
//  SettingsView.swift
//  NativeMaintenanceNote
//
//  Web版バックアップのインポート導線と通知設定。
//  エクスポート・about等はPhase 9で拡充予定。
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isPresentingFileImporter = false
    @State private var pendingDTO: BackupDTO?
    @State private var pendingPreview: ImportPreview?
    @State private var isImporting = false
    @State private var summaryToShowAfterDismiss: ImportSummary?
    @State private var importSummary: ImportSummary?
    @State private var errorMessage: String?

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var leadDays = NotificationScheduler.leadDays

    var body: some View {
        List {
            Section("通知") {
                switch authorizationStatus {
                case .authorized, .provisional:
                    LabeledContent("通知の許可", value: "許可済み")
                    Stepper("何日前に通知するか: \(leadDays)日前", value: $leadDays, in: 1...30)
                        .onChange(of: leadDays) { _, newValue in
                            NotificationScheduler.leadDays = newValue
                            NotificationScheduler.rescheduleAll(context: modelContext)
                        }
                case .denied:
                    LabeledContent("通知の許可", value: "許可されていません")
                    Text("端末の設定アプリから通知を許可してちょうだい。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    Button("通知を許可する") {
                        NotificationScheduler.requestAuthorization { _ in
                            refreshAuthorizationStatus()
                            NotificationScheduler.rescheduleAll(context: modelContext)
                        }
                    }
                }
            }

            Section("データ移行") {
                Button("Web版バックアップをインポート") {
                    isPresentingFileImporter = true
                }
            }
        }
        .navigationTitle("設定")
        .onAppear { refreshAuthorizationStatus() }
        .fileImporter(isPresented: $isPresentingFileImporter, allowedContentTypes: [.json]) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: Binding(
            get: { pendingPreview != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDTO = nil
                    pendingPreview = nil
                }
            }
        ), onDismiss: {
            if let summaryToShowAfterDismiss {
                importSummary = summaryToShowAfterDismiss
                self.summaryToShowAfterDismiss = nil
            }
        }) {
            if let pendingPreview {
                NavigationStack {
                    ImportPreviewView(
                        preview: pendingPreview,
                        isImporting: isImporting,
                        onConfirm: confirmImport,
                        onCancel: {
                            self.pendingDTO = nil
                            self.pendingPreview = nil
                        }
                    )
                }
            }
        }
        .alert("インポート完了", isPresented: Binding(
            get: { importSummary != nil },
            set: { isPresented in if !isPresented { importSummary = nil } }
        )) {
            Button("OK") {}
        } message: {
            if let importSummary {
                Text("バイク\(importSummary.bikeCount)件、整備記録\(importSummary.maintenanceRecordCount)件、保険記録\(importSummary.insuranceRecordCount)件、給油記録\(importSummary.refuelRecordCount)件を取り込みました。")
            }
        }
        .alert("インポートエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in if !isPresented { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let dto = try BackupImporter.decode(data)
                pendingDTO = dto
                pendingPreview = BackupImporter.preview(dto, context: modelContext)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func confirmImport() {
        guard let pendingDTO else { return }
        isImporting = true
        let summary = BackupImporter.execute(pendingDTO, context: modelContext)
        do {
            try modelContext.save()
            NotificationScheduler.rescheduleAll(context: modelContext)
            isImporting = false
            summaryToShowAfterDismiss = summary
            self.pendingDTO = nil
            self.pendingPreview = nil
        } catch {
            isImporting = false
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAuthorizationStatus() {
        NotificationScheduler.authorizationStatus { status in
            authorizationStatus = status
        }
    }
}

private struct ImportPreviewView: View {
    let preview: ImportPreview
    let isImporting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            Section("取り込み件数") {
                LabeledContent("バイク", value: "\(preview.bikeCount)件")
                LabeledContent("整備記録", value: "\(preview.maintenanceRecordCount)件")
                LabeledContent("保険記録", value: "\(preview.insuranceRecordCount)件")
                LabeledContent("給油記録", value: "\(preview.refuelRecordCount)件")
            }
            if !preview.newMakerNames.isEmpty {
                Section("新規作成されるメーカー") {
                    ForEach(preview.newMakerNames, id: \.self) { Text($0) }
                }
            }
            if !preview.newShopNames.isEmpty {
                Section("新規作成される店舗") {
                    ForEach(preview.newShopNames, id: \.self) { Text($0) }
                }
            }
            if !preview.newMaintenanceTypeNames.isEmpty {
                Section("新規作成される整備タイプ") {
                    ForEach(preview.newMaintenanceTypeNames, id: \.self) { Text($0) }
                }
            }
            if !preview.newMaintenancePartNames.isEmpty {
                Section("新規作成される整備部品") {
                    ForEach(preview.newMaintenancePartNames, id: \.self) { Text($0) }
                }
            }
            if !preview.newInsuranceTypeNames.isEmpty {
                Section("新規作成される保険タイプ") {
                    ForEach(preview.newInsuranceTypeNames, id: \.self) { Text($0) }
                }
            }
            Section {
                Text("バイク・整備記録・保険記録・給油記録は常に新規追加されます。同じファイルを2回インポートすると重複するのでご注意ください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("インポート内容の確認")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("インポート実行") { onConfirm() }
                    .disabled(isImporting)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Bike.self, Maker.self, Shop.self], inMemory: true)
}
