import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let database = Logger(subsystem: subsystem, category: "Database")
}