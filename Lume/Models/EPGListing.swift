import Foundation
import SwiftData

@Model
final class EPGListing {
    @Attribute(.unique) var id: String
    var epgId: String
    var title: String
    var listingDescription: String
    var start: Date
    var end: Date
    
    var liveStream: LiveStream?
    
    init(id: String, epgId: String, title: String, listingDescription: String, start: Date, end: Date, liveStream: LiveStream? = nil) {
        self.id = id
        self.epgId = epgId
        self.title = title
        self.listingDescription = listingDescription
        self.start = start
        self.end = end
        self.liveStream = liveStream
    }
}
