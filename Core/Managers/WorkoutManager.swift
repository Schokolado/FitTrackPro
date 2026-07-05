import SwiftUI
import SwiftData

@Observable
class WorkoutManager {
    static let shared = WorkoutManager()
    
    var activeSession: WorkoutSession?
    var activeViewModel: WorkoutSessionViewModel?
    
    var isWorkoutActive: Bool {
        activeSession != nil
    }
    
    private init() {}
    
    func startWorkout(session: WorkoutSession) {
        self.activeSession = session
        let vm = WorkoutSessionViewModel()
        vm.startWorkout()
        self.activeViewModel = vm
    }
    
    func endWorkout() {
        self.activeViewModel?.pauseWorkout()
        LiveActivityManager.shared.endWorkoutActivity()
        self.activeSession = nil
        self.activeViewModel = nil
    }
    
    func resumeUnfinishedWorkout(session: WorkoutSession) {
        self.activeSession = session
        let vm = WorkoutSessionViewModel()
        
        // Timer should continue exactly from when the workout was started
        vm.accumulatedTime = Date().timeIntervalSince(session.startTime)
        
        vm.startWorkout()
        self.activeViewModel = vm
    }
}

import ActivityKit

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

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<WorkoutLiveActivityAttributes>?
    
    private init() {}
    
    func startWorkoutActivity(workoutName: String, startDate: Date, accumulatedTime: TimeInterval = 0, isRestTimerActive: Bool = false, restTargetTime: Date? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let existingActivities = Activity<WorkoutLiveActivityAttributes>.activities
        Task {
            for activity in existingActivities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        let attributes = WorkoutLiveActivityAttributes(workoutName: workoutName)
        let initialContentState = WorkoutLiveActivityAttributes.ContentState(isPaused: false, accumulatedTime: accumulatedTime, lastStartTime: startDate, isRestTimerActive: isRestTimerActive, restTargetTime: restTargetTime)
        do {
            if #available(iOS 16.2, *) {
                let activityContent = ActivityContent(state: initialContentState, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: activityContent, pushType: nil)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: initialContentState, pushType: nil)
            }
        } catch {}
    }
    
    func updateWorkoutActivity(isPaused: Bool, accumulatedTime: TimeInterval, lastStartTime: Date?, isRestTimerActive: Bool, restTargetTime: Date?) {
        guard let activity = currentActivity else { return }
        let updatedContentState = WorkoutLiveActivityAttributes.ContentState(isPaused: isPaused, accumulatedTime: accumulatedTime, lastStartTime: lastStartTime, isRestTimerActive: isRestTimerActive, restTargetTime: restTargetTime)
        Task {
            if #available(iOS 16.2, *) {
                let activityContent = ActivityContent(state: updatedContentState, staleDate: nil)
                await activity.update(activityContent)
            } else {
                await activity.update(using: updatedContentState)
            }
        }
    }
    
    func endWorkoutActivity() {
        let finalContentState = WorkoutLiveActivityAttributes.ContentState(isPaused: true, accumulatedTime: 0, lastStartTime: nil, isRestTimerActive: false, restTargetTime: nil)
        Task {
            for activity in Activity<WorkoutLiveActivityAttributes>.activities {
                if #available(iOS 16.2, *) {
                    let activityContent = ActivityContent(state: finalContentState, staleDate: nil)
                    await activity.end(activityContent, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalContentState, dismissalPolicy: .immediate)
                }
            }
            currentActivity = nil
        }
    }
}
