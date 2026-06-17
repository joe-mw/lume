//
//  EPGSourceReconciler.swift
//  Lume
//
//  Keeps each playlist's EPG source in step with the playlist. When a playlist
//  is added or edited, its guide URL (Xtream `xmltv.php` or m3u `url-tvg`)
//  becomes a standalone `EPGSource`; when the playlist loses its guide URL or is
//  deleted, that source is removed. Manual sources the user adds in EPG settings
//  carry no `playlistID` and are never touched here.
//

import Foundation
import OSLog
import SwiftData

/// `nonisolated` so it runs on whichever context the caller already has — the
/// main-actor Settings/login flows and the sync actor's discovery hook both use
/// the same reconciliation.
nonisolated enum EPGSourceReconciler {
    /// Creates, updates, or removes the EPG source linked to `playlist` so it
    /// matches the playlist's current guide configuration. Idempotent.
    static func reconcile(_ playlist: Playlist, in context: ModelContext) {
        let playlistID = playlist.id
        let existing = linkedSource(playlistID: playlistID, in: context)

        guard let desiredURL = guideURL(for: playlist) else {
            if let existing {
                context.delete(existing)
                try? context.save()
                Logger.sync.info("Removed EPG source for playlist with no guide URL")
            }
            return
        }

        if let existing {
            // Preserve the user's enabled choice; only refresh the derived fields.
            existing.name = sourceName(for: playlist)
            existing.url = desiredURL
        } else {
            context.insert(EPGSource(name: sourceName(for: playlist), url: desiredURL, playlistID: playlistID))
        }
        try? context.save()
    }

    /// Removes a playlist's linked EPG source. Called from `PlaylistDeletion`.
    static func remove(playlistID: UUID, in context: ModelContext) {
        guard let source = linkedSource(playlistID: playlistID, in: context) else { return }
        context.delete(source)
    }

    /// The XMLTV URL that should back `playlist`'s guide, or nil when it has none.
    static func guideURL(for playlist: Playlist) -> String? {
        switch playlist.sourceType {
        case .xtream:
            return XtreamClient.xmltvURL(for: playlist)?.absoluteString
        case .m3u:
            guard let epgURL = playlist.epgURL, !epgURL.isEmpty else { return nil }
            return epgURL
        }
    }

    private static func sourceName(for playlist: Playlist) -> String {
        playlist.name
    }

    private static func linkedSource(playlistID: UUID, in context: ModelContext) -> EPGSource? {
        // Filter in memory rather than via a #Predicate: the source set is tiny
        // (one per playlist plus a few manual entries), and an optional-UUID
        // predicate comparison is brittle to translate.
        let all = (try? context.fetch(FetchDescriptor<EPGSource>())) ?? []
        return all.first { $0.playlistID == playlistID }
    }
}
