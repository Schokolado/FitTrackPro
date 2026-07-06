import ActivityKit
import Foundation

public struct WorkoutLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var isPaused: Bool
        public var accumulatedTime: TimeInterval
        public var lastStartTime: Date?
        public var isRestTimerActive: Bool
        public var restTargetTime: Date?
        
        public init(isPaused: Bool, accumulatedTime: TimeInterval, lastStartTime: Date?, isRestTimerActive: Bool = false, restTargetTime: Date? = nil) {
            self.isPaused = isPaused
            self.accumulatedTime = accumulatedTime
            self.lastStartTime = lastStartTime
            self.isRestTimerActive = isRestTimerActive
            self.restTargetTime = restTargetTime
        }
    }

    public var workoutName: String
    
    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}
