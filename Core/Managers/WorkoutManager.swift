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
        self.activeSession = nil
        self.activeViewModel = nil
    }
    
    func resumeUnfinishedWorkout(session: WorkoutSession) {
        // Find latest timestamp among sets to estimate accumulated time
        var latestSetTime: Date = session.startTime
        if let sets = session.sets {
            for set in sets {
                if set.timestamp > latestSetTime {
                    latestSetTime = set.timestamp
                }
            }
        }
        
        let estimatedElapsed = latestSetTime.timeIntervalSince(session.startTime)
        
        self.activeSession = session
        let vm = WorkoutSessionViewModel()
        vm.accumulatedTime = estimatedElapsed
        vm.startWorkout()
        self.activeViewModel = vm
    }
}
