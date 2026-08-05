//
//  LocationVerificationView.swift
//  NativeMaintenanceNote
//
//  実機でのBackground Modes（GPS）検証結果を確認するための画面。
//  docs/HANDOFF.md §8 アクション1の検証に使う。検証完了後は削除・置き換えを想定。
//

import CoreLocation
import SwiftUI

struct LocationVerificationView: View {
    @State private var logger = LocationLogger.shared

    var body: some View {
        List {
            Section("権限・監視状態") {
                LabeledContent("権限状態", value: logger.authorizationStatus.description)
                LabeledContent("監視中", value: logger.isMonitoring ? "はい" : "いいえ")

                Button("使用中のみ許可をリクエスト") {
                    logger.requestWhenInUseAuthorization()
                }
                Button("常に許可をリクエスト") {
                    logger.requestAlwaysAuthorization()
                }

                if logger.isMonitoring {
                    Button("監視を停止", role: .destructive) {
                        logger.stopMonitoring()
                    }
                } else {
                    Button("Significant-Change監視を開始") {
                        logger.startMonitoring()
                    }
                }
            }

            Section("ログ（\(logger.entries.count)件）") {
                if logger.entries.isEmpty {
                    Text("まだログがありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(logger.entries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.event)
                                .font(.body)
                            if let lat = entry.latitude, let lon = entry.longitude {
                                Text("緯度\(lat, specifier: "%.5f") 経度\(lon, specifier: "%.5f")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("GPS検証")
        .toolbar {
            ToolbarItem {
                Button("ログをクリア", role: .destructive) {
                    logger.clearLog()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LocationVerificationView()
    }
}
