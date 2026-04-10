//
//  LumeMigrationPlan.swift
//  Lume
//
//  SwiftData migration plan for schema evolution
//

import Foundation
import SwiftData

enum LumeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LumeSchemaV1.self, LumeSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: LumeSchemaV1.self,
        toVersion: LumeSchemaV2.self
    )
}

// MARK: - Helper Extensions

extension LumeSchemaV2 {
    /// Sync status enumeration
    enum SyncStatus: String, Codable {
        case idle
        case syncing
        case error
    }

    /// Download status enumeration
    enum DownloadStatus: String, Codable {
        case pending
        case downloading
        case completed
        case failed
    }
}

// MARK: - Computed Properties for V2 Models

extension LumeSchemaV2.Playlist {
    var syncStatus: LumeSchemaV2.SyncStatus {
        get { LumeSchemaV2.SyncStatus(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }
}

extension LumeSchemaV2.Movie {
    var downloadStatus: LumeSchemaV2.DownloadStatus? {
        get {
            guard let raw = downloadStatusRaw else { return nil }
            return LumeSchemaV2.DownloadStatus(rawValue: raw)
        }
        set { downloadStatusRaw = newValue?.rawValue }
    }
}

extension LumeSchemaV2.Episode {
    var downloadStatus: LumeSchemaV2.DownloadStatus? {
        get {
            guard let raw = downloadStatusRaw else { return nil }
            return LumeSchemaV2.DownloadStatus(rawValue: raw)
        }
        set { downloadStatusRaw = newValue?.rawValue }
    }
}
