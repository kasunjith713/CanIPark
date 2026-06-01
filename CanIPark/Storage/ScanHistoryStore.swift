// ScanHistoryStore.swift
// CanIPark
//
// Persists scan history to UserDefaults as JSON.

import Foundation
import SwiftUI

@Observable
final class ScanHistoryStore {

    // MARK: - Storage

    private static let storageKey = "com.canipark.scanHistory"
    private static let maxEntries = 100

    private(set) var scans: [ParkingAnalysisResult] = []

    // MARK: - Thumbnail cache (in-memory only)

    /// Maps scan id -> JPEG data for the captured photo thumbnail.
    private(set) var thumbnails: [UUID: Data] = [:]

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Public API

    func add(_ result: ParkingAnalysisResult, thumbnailData: Data? = nil) {
        scans.insert(result, at: 0)
        if let data = thumbnailData {
            thumbnails[result.id] = data
        }
        trimIfNeeded()
        save()
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { scans[$0].id }
        scans.remove(atOffsets: offsets)
        for id in ids {
            thumbnails.removeValue(forKey: id)
            removeThumbnailFromDisk(id: id)
        }
        save()
    }

    func delete(id: UUID) {
        scans.removeAll { $0.id == id }
        thumbnails.removeValue(forKey: id)
        removeThumbnailFromDisk(id: id)
        save()
    }

    func clearAll() {
        let ids = scans.map(\.id)
        scans.removeAll()
        for id in ids {
            thumbnails.removeValue(forKey: id)
            removeThumbnailFromDisk(id: id)
        }
        save()
    }

    func thumbnail(for id: UUID) -> UIImage? {
        if let data = thumbnails[id] {
            return UIImage(data: data)
        }
        if let data = loadThumbnailFromDisk(id: id) {
            thumbnails[id] = data
            return UIImage(data: data)
        }
        return nil
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(scans)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("[ScanHistoryStore] Failed to encode scans: \(error)")
        }
        // Save thumbnails to disk
        for (id, data) in thumbnails {
            saveThumbnailToDisk(id: id, data: data)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            scans = try JSONDecoder().decode([ParkingAnalysisResult].self, from: data)
        } catch {
            print("[ScanHistoryStore] Failed to decode scans: \(error)")
            scans = []
        }
    }

    private func trimIfNeeded() {
        if scans.count > Self.maxEntries {
            let removed = scans.suffix(from: Self.maxEntries)
            for scan in removed {
                thumbnails.removeValue(forKey: scan.id)
                removeThumbnailFromDisk(id: scan.id)
            }
            scans = Array(scans.prefix(Self.maxEntries))
        }
    }

    // MARK: - Thumbnail Disk Storage

    private var thumbnailDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScanThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func thumbnailURL(for id: UUID) -> URL {
        thumbnailDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    private func saveThumbnailToDisk(id: UUID, data: Data) {
        let url = thumbnailURL(for: id)
        try? data.write(to: url)
    }

    private func loadThumbnailFromDisk(id: UUID) -> Data? {
        let url = thumbnailURL(for: id)
        return try? Data(contentsOf: url)
    }

    private func removeThumbnailFromDisk(id: UUID) {
        let url = thumbnailURL(for: id)
        try? FileManager.default.removeItem(at: url)
    }
}
