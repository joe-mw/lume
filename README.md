# Lume - the IPTV player for iOS and macOS

## General
Lume is an IPTV player for iOS and macOS (tvOS support planned). It supports xtream playlists, EPG data, and various streaming formats. Lume is built using SwiftUI, SwiftData and KSPlayer, providing a modern and intuitive user interface.


## Features
- **Xtream Playlist Support** — Add, manage, and sync multiple Xtream playlists
- **Live TV** — Browse channels by category with EPG data display, channel logos, and catchup support
- **Movies & Series** — Browse by categories with detailed metadata (rating, cast, plot, release date, etc.)
- **Global Search** — Fast search across movies, series, and live channels with filter picker
- **Watch Progress** — Automatic progress tracking with resume playback and auto-mark-watched at 90%
- **Favorites & Watchlist** — Mark movies, series, and channels as favorites or watched
- **Dual-Player Engine** — Choose between AVPlayer (native) and KSPlayer (FFmpeg-based) with user preference
- **Multi-Platform** — Native support for iOS and macOS with platform-adaptive UI
- **Content Sync** — Background sync engine with step-by-step progress for all content types
- **Sorting & Organization** — Configurable sort options for categories and content
- **Modern SwiftUI** — Clean interface following latest SwiftUI design patterns with Liquid Glass aesthetics

## Layout

### General
- The app has a clean and modern design, following the latest SwiftUI design patterns and best practices (including liquid glass)
- Tab-based navigation with sections for Live TV, Movies, TV Shows, and Settings. Search is available across all content types.
- Each section has its own view with consistent navigation patterns
- Settings in the tab bar (gear icon)
- Title of the active section in the top center of the screen

### Live TV
- Channel categories (from playlist). On click, the category is opened and all channels are shown with channel logo, name and EPG data (current and next show). On click on a channel, the player opens and the stream starts playing.
- Recently watched and favorite channels (planned, tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues))

### Movies
- Sections for different categories (continue watching, trending, recently added, etc.)
- Each section will have a horizontal scrollable list of movies with their poster - resulting in a clean look.
- On click on a movie, the movie details view will be opened

### TV Shows
- Features similar to the movies
- Within a show, the user will be able to select the season and episode

#### Movie / Show Details
- Movie or show poster, title, description, rating, cast, director, plot, genre, release date, duration
- Play / Resume button to start playback
- On play, the app checks availability in the xtream playlist. If multiple streams are available (different qualities), the user can choose.
- Season and episode selection for TV shows with per-episode progress tracking
- Ratings display (from Xtream playlist)
- Cast and director information display
- YouTube trailer link (full trailer player planned — tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues))
- Related and recommended movies/shows (planned — tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues))

##### View
- Header icons: Back button on the left. Favorite (heart icon) and watched (eye icon) toggle buttons on the right.
- Poster
- Title (or logo if available)
- Play / Resume button
- Year and Duration
- Description
- Ratings section (IMDB, Rotten Tomatoes, etc.) (planned — tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues))
- Trailers (planned — tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues))
- Cast
- Related movies/shows (planned — tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues))

### Settings
Manage Xtream playlists (add, edit, delete, sync) with server info display (status, active connections, expiry date). Customize the player engine (AVPlayer / KSPlayer). Additional settings like appearance themes, content management (hide/reorder categories), and player preferences (aspect ratio, subtitles) are planned — tracked in [GitHub Issues](https://github.com/bilipp/Lume/issues).

## Content indexing
The app indexes content from the xtream playlist and EPG data locally using SwiftData, enabling fast searching and offline browsing. Progressive tracking and watch history are already supported, with personalized recommendations, hide/show categories, and reordering planned through [GitHub Issues](https://github.com/bilipp/Lume/issues).

## Future Plans
Upcoming features and enhancements are tracked as [GitHub Issues](https://github.com/bilipp/Lume/issues). Key planned items include a home screen dashboard, Trakt and TMDB integration, downloads for offline viewing, iCloud sync, m3u support, parental controls, Chromecast support, and more.

## Testing

### Test Suite
Lume has **~173 tests** spanning unit tests (Swift Testing) and UI tests (XCTest).

| Target | Tests | Type | Framework |
|---|---|---|---|
| `LumeTests` | 129 | Unit / Integration | Swift Testing |
| `LumeUITests` | ~44 | UI Automation | XCTest |

### Test Contents

**DTO Decoding (17 tests)** — Decodes all 8 real API payloads from `ExampleData/` (Movies: 13,955; Live Streams: 2,568; Series: 2,215). Verifies JSON→Swift model mapping and type coercion (Int-as-String, String-as-Double, Unix timestamps).

**URL Building (11 tests)** — Validates movie, episode, live stream, and catchup URL formats, trailing slash handling, and special characters in credentials.

**API Client (16 tests)** — Tests `Endpoint.asURLRequest()` construction, `NetworkError` descriptions and retriable classification, `RetryBackoff` linear/exponential delay math.

**Model Layer (13 tests)** — SwiftData `@Attribute(.unique)` upsert, computed properties, Category ID construction, Playlist sync status transitions.

**Sort Options (17 tests)** — All `CategorySortOption`/`ContentSortOption` permutations, empty/duplicate arrays, label and icon validation.

**Playable Media (9 tests)** — Factory methods, Codable round-trip, Hashable conformance.

**Sync Progress (13 tests)** — State machine (`pending`→`active`→`completed`), `overallFraction` computation, all 7 `SyncSteps`.

**Content Sync (8 tests)** — Large-batch performance (13,900 movies < 30s), upsert deduplication, empty/single edge cases.

**Player Settings (4 tests)** — `PlayerEngineKind` all cases, display names, storage key.

**UI Tests (~44 tests)** — App launch and performance, login flow, tab navigation (Live TV, Movies, Series, Settings), playlist detail view, settings controls.

### Running Tests

```bash
# Unit tests only
xcodebuild test -project Lume.xcodeproj -scheme Lume \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LumeTests

# UI tests only
xcodebuild test -project Lume.xcodeproj -scheme Lume \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LumeUITests

# All tests
xcodebuild test -project Lume.xcodeproj -scheme Lume \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Test Helpers
Shared utilities in `LumeTests/Helpers/TestHelpers.swift`:
- **`loadExampleJSON<T>(_:)`** — Loads and decodes any file from `ExampleData/` using `#filePath`-based navigation (no bundle resource setup needed)
- **`makeTestContainer()`** — Creates an in-memory `ModelContainer` with all 7 SwiftData model types
- **`exampleDataURL(_:)`** — Resolves a filename to its full path relative to the test target

### Testing Strategy
Full strategy document available in [`TestingStrategy.md`](TestingStrategy.md), covering priority matrix, file organization, and CI setup.

## Xtream Codes API Documentation
For more information on the Xtream Codes API, please refer to the [Xtream Codes API Documentation](XtreamAPI.md) file, which provides detailed information on the available endpoints, authentication, and response formats for retrieving server information, live streams, video-on-demand content, series, and EPG data.