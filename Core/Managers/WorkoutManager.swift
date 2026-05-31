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
}
