//
//  RecommendationFeedback.swift
//  Lume
//
//  A user's up/down vote on a "For You" recommendation. Lives in the local-only
//  catalog store — the recommendations engine runs entirely on-device, so this
//  feedback never leaves the device. Scoped by `profileID` so each profile keeps
//  its own taste; an absent id means the pre-profiles default.
//

import Foundation
import SwiftData

/// Which way the user voted on a recommendation.
enum RecommendationVote: Int, Codable {
    case upvote = 1
    case downvote = -1
}

@Model
final class RecommendationFeedback {
    // Every read scopes by the active profile and looks up a single content id;
    // index both so the engine seeks instead of scanning.
    #Index<RecommendationFeedback>([\.profileID], [\.contentId])

    /// Composite `profile#content` key, so a profile has at most one vote per
    /// title and re-voting upserts in place. Local store only — `@Attribute(.unique)`
    /// is safe here (it never mirrors to CloudKit).
    @Attribute(.unique) var id: String

    var contentId: String = ""
    var profileID: UUID?
    var voteRaw: Int = RecommendationVote.upvote.rawValue
    var updatedAt: Date = Date()

    var vote: RecommendationVote {
        get { RecommendationVote(rawValue: voteRaw) ?? .upvote }
        set { voteRaw = newValue.rawValue }
    }

    init(contentId: String, profileID: UUID?, vote: RecommendationVote, updatedAt: Date = Date()) {
        id = Self.identity(contentId: contentId, profileID: profileID)
        self.contentId = contentId
        self.profileID = profileID
        voteRaw = vote.rawValue
        self.updatedAt = updatedAt
    }

    /// The composite key for a (profile, content) pair.
    static func identity(contentId: String, profileID: UUID?) -> String {
        "\(profileID?.uuidString ?? "default")#\(contentId)"
    }
}
