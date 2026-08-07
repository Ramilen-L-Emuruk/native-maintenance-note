//
//  ImageStore.swift
//  NativeMaintenanceNote
//
//  バイク・整備記録等の画像は、SwiftDataストアの肥大化を避けるため
//  Application Support配下にファイルとして保存し、モデルはファイル名の
//  配列のみを保持する(docs/HANDOFF.mdに基づく設計判断)。
//

import Foundation

enum ImageStore {
    private static var directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    @discardableResult
    static func save(_ data: Data, filenameExtension: String = "jpg") throws -> String {
        let filename = "\(UUID().uuidString).\(filenameExtension)"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    static func load(_ filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }
}
