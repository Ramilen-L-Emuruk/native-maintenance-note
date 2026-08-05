//
//  LocationLogger.swift
//  NativeMaintenanceNote
//
//  実機でのBackground Modes（GPS）検証用の最小スキャフォールド。
//  Significant-Change Location Serviceの発火・権限状態の変化・
//  アプリのバックグラウンド再起動をログとして残し、画面で確認できるようにする。
//  データモデル設計より前の検証専用コードのため、正式なCRUD層とは統合しない。
//

import CoreLocation
import Foundation

struct LocationLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let event: String
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?

    init(event: String, location: CLLocation? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.horizontalAccuracy = location?.horizontalAccuracy
    }
}

@Observable
final class LocationLogger: NSObject, CLLocationManagerDelegate {
    static let shared = LocationLogger()

    private static let entriesKey = "LocationLogger.entries"
    private static let monitoringEnabledKey = "LocationLogger.monitoringEnabled"
    private static let maxEntries = 200

    private let manager = CLLocationManager()

    private(set) var entries: [LocationLogEntry] = []
    private(set) var authorizationStatus: CLAuthorizationStatus

    var isMonitoring: Bool {
        UserDefaults.standard.bool(forKey: Self.monitoringEnabledKey)
    }

    private override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        entries = Self.loadEntries()

        // 監視フラグが立っていれば、バックグラウンド再起動時にも自動で監視を再開する。
        if isMonitoring {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startMonitoring() {
        UserDefaults.standard.set(true, forKey: Self.monitoringEnabledKey)
        manager.startMonitoringSignificantLocationChanges()
        append(event: "監視開始")
    }

    func stopMonitoring() {
        UserDefaults.standard.set(false, forKey: Self.monitoringEnabledKey)
        manager.stopMonitoringSignificantLocationChanges()
        append(event: "監視停止")
    }

    func clearLog() {
        entries = []
        Self.saveEntries(entries)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        append(event: "権限変化: \(authorizationStatus.description)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        append(event: "位置更新", location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        append(event: "エラー: \(error.localizedDescription)")
    }

    // MARK: - Private

    private func append(event: String, location: CLLocation? = nil) {
        let entry = LocationLogEntry(event: event, location: location)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        Self.saveEntries(entries)
    }

    private static func loadEntries() -> [LocationLogEntry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([LocationLogEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func saveEntries(_ entries: [LocationLogEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: entriesKey)
    }
}

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "未決定"
        case .restricted: return "制限あり"
        case .denied: return "拒否"
        case .authorizedAlways: return "常に許可"
        case .authorizedWhenInUse: return "使用中のみ許可"
        @unknown default: return "不明"
        }
    }
}
