import Foundation

enum PlayerEngineKind: String, CaseIterable, Identifiable {
    case ksPlayer
    case avPlayer

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .ksPlayer: return "KSPlayer"
        case .avPlayer: return "AVPlayer"
        }
    }

    var subtitle: String {
        switch self {
        case .ksPlayer: return "FFmpeg-backed. Recommended for IPTV streams."
        case .avPlayer: return "Native Apple player. Best for HLS and MP4."
        }
    }

    static var defaultValue: PlayerEngineKind {
        #if canImport(KSPlayer)
            return .ksPlayer
        #else
            return .avPlayer
        #endif
    }
}

enum PlayerSettings {
    static let engineKey = "player.engine"
}
