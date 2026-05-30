import Testing
import Foundation
@testable import Lume

struct PlayerSettingsTests {

    @Test func engineKindAllCases() {
        #expect(PlayerEngineKind.allCases.count == 2)
        #expect(PlayerEngineKind.ksPlayer.rawValue == "ksPlayer")
        #expect(PlayerEngineKind.avPlayer.rawValue == "avPlayer")
    }

    @Test func engineKindDisplayNames() {
        #expect(PlayerEngineKind.ksPlayer.displayName == "KSPlayer")
        #expect(PlayerEngineKind.avPlayer.displayName == "AVPlayer")
    }

    @Test func engineKindIdentifiable() {
        #expect(PlayerEngineKind.ksPlayer.id == "ksPlayer")
        #expect(PlayerEngineKind.avPlayer.id == "avPlayer")
    }

    @Test func engineKindSubtitlesNotEmpty() {
        for kind in PlayerEngineKind.allCases {
            #expect(!kind.subtitle.isEmpty)
        }
    }

    @Test func engineKindSubtitleContent() {
        #expect(PlayerEngineKind.ksPlayer.subtitle.contains("FFmpeg"))
        #expect(PlayerEngineKind.avPlayer.subtitle.contains("Native"))
    }

    @Test func engineStorageKey() {
        #expect(PlayerSettings.engineKey == "player.engine")
    }
}
