//
//  EPGSyncService.swift
//  Lume
//
//  Owns the background EPG refresh task and publishes whether one is running,
//  for the EPG settings screen. Singleton because it must outlive any one view
//  and be reachable from launch, the content-sync completion hook, and the
//  manual "Sync Now" button.
//

import Foundation
import Observation
import OSLog
import SwiftData

@Observable
final class EPGSyncService {
    static let shared = EPGSyncService()

    private(set) var isSyncing = false

    private var container: ModelContainer?
    private var task: Task<Void, Never>?

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    /// Manual trigger (settings "Sync Now"): refreshes now regardless of the
    /// schedule.
    func syncNow() {
        kick()
    }

    /// Background trigger (launch / after a content sync): refreshes only if the
    /// guide is stale per the EPG frequency setting.
    func syncIfDue() {
        guard isDue else { return }
        kick()
    }

    private var isDue: Bool {
        let raw = UserDefaults.standard.string(forKey: SyncFrequency.epgStorageKey) ?? ""
        let frequency = SyncFrequency.resolveEPG(raw)
        return frequency.isDue(lastSyncDate: EPGSyncSchedule.lastSyncDate)
    }

    private func kick() {
        guard let container, task == nil else { return }
        isSyncing = true
        let manager = EPGSyncManager(modelContainer: container)
        // Background guide refresh: run below the UI so an in-flight sync (which
        // saves into the shared catalog container, churning browse `@Query`s)
        // yields CPU to the main thread instead of competing with it. The
        // profile showed EPG ingest pegging a background thread at 100% in
        // lockstep with a frozen main thread right after a playlist sync.
        task = Task(priority: .utility) {
            let succeeded = await manager.syncAllSources()
            if succeeded {
                EPGSyncSchedule.lastSyncDate = Date()
            }
            isSyncing = false
            task = nil
            Logger.database.info("EPG refresh finished (success: \(succeeded))")
        }
    }
}
