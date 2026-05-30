import Foundation
import os.log

// MARK: - App Logger
// Replaces bare print() calls with structured os_log output.
// Usage: AppLogger.services.error("Failed to save: \(error)")

enum AppLogger {
    static let services = Logger(subsystem: "com.fittrackpro.app", category: "Services")
    static let workout  = Logger(subsystem: "com.fittrackpro.app", category: "Workout")
    static let data     = Logger(subsystem: "com.fittrackpro.app", category: "Data")
}
