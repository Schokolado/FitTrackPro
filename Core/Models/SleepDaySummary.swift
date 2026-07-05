import Foundation

struct SleepDaySummary: Equatable {
    let date: Date
    let bedTime: Date?
    let wakeTime: Date?
    let totalDurationMinutes: Double
    let awakeMinutes: Double
    let remMinutes: Double
    let coreMinutes: Double
    let deepMinutes: Double
    let unspecifiedMinutes: Double
    let sessions: [SleepSession]
    
    // For HealthKit data
    init(date: Date, bedTime: Date?, wakeTime: Date?, totalDurationMinutes: Double, awakeMinutes: Double, remMinutes: Double, coreMinutes: Double, deepMinutes: Double, unspecifiedMinutes: Double, sessions: [SleepSession]) {
        self.date = date
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.totalDurationMinutes = totalDurationMinutes
        self.awakeMinutes = awakeMinutes
        self.remMinutes = remMinutes
        self.coreMinutes = coreMinutes
        self.deepMinutes = deepMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
        self.sessions = sessions
    }
    
    // Fallback for manual entries
    init(date: Date, totalDurationMinutes: Double, bedTime: Date? = nil, wakeTime: Date? = nil) {
        self.date = date
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.totalDurationMinutes = totalDurationMinutes
        self.awakeMinutes = 0
        self.remMinutes = 0
        self.coreMinutes = 0
        self.deepMinutes = 0
        self.unspecifiedMinutes = 0
        self.sessions = []
    }
    
    var hasDetailedPhases: Bool {
        return (remMinutes > 0 || coreMinutes > 0 || deepMinutes > 0 || awakeMinutes > 0)
    }
}

struct SleepSession: Equatable, Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let durationMinutes: Double // Actual sleep duration, not just endDate - startDate
}
