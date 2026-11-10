import SwiftUI
import SwiftData

@Observable
class WorkoutSessionViewModel {
    /// Separated timer model so timer state changes only redraw timer UI components
    /// and active second-by-second ticks run natively in CoreAnimation via `Text(timerInterval:)`.
    let timer = WorkoutTimerViewModel()
    
    var accumulatedTime: TimeInterval {
        get { timer.accumulatedTime }
        set { timer.accumulatedTime = newValue }
    }
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        timer.onRestTimerExpired = { [weak self] in
            self?.handleRestTimerExpired()
        }
    }
    
    func startWorkout() {
        timer.start()
        
        if let session = WorkoutManager.shared.activeSession {
            LiveActivityManager.shared.startWorkoutActivity(
                workoutName: session.plan?.name ?? "Freies Training",
                startDate: timer.currentSegmentStartTime ?? Date(),
                accumulatedTime: timer.accumulatedTime,
                isRestTimerActive: timer.restTimerActive,
                restTargetTime: timer.restTargetTime
            )
        }
    }
    
    private func updateLiveActivity() {
        LiveActivityManager.shared.updateWorkoutActivity(
            isPaused: !timer.timerActive,
            accumulatedTime: timer.accumulatedTime,
            lastStartTime: timer.currentSegmentStartTime,
            isRestTimerActive: timer.restTimerActive,
            restTargetTime: timer.restTargetTime
        )
    }
    
    func pauseWorkout() {
        let hadActiveRest = timer.restTimerActive && !timer.restTimerPaused
        timer.pause()
        
        if hadActiveRest {
            NotificationService.shared.cancelRestTimerNotification()
        }
        
        // HKWorkoutSession pausieren
        HealthKitService.shared.pauseLiveWorkoutSession()
        
        updateLiveActivity()
    }
    
    func resumeWorkout() {
        let hadPausedRest = timer.restTimerActive && timer.restTimerPaused
        timer.resume()
        
        if hadPausedRest && timer.restTimerActive && !timer.restTimerPaused {
            let remaining = timer.currentRestRemaining
            if remaining > 0 {
                NotificationService.shared.scheduleRestTimerNotification(duration: remaining)
            }
        }
        
        // HKWorkoutSession fortsetzen
        HealthKitService.shared.resumeLiveWorkoutSession()
        
        updateLiveActivity()
    }
    
    func finishWorkout() {
        timer.finishAll()
        NotificationService.shared.cancelRestTimerNotification()
        endRestBackgroundTask()
        LiveActivityManager.shared.endWorkoutActivity()
    }
    
    // MARK: - Rest Timer
    func startRestTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        timer.startRestTimer(duration: duration)
        
        NotificationService.shared.scheduleRestTimerNotification(duration: duration)
        updateLiveActivity()
        
        endRestBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "RestTimer") { [weak self] in
            self?.endRestBackgroundTask()
        }
    }
    
    func cancelRestTimer() {
        timer.cancelRestTimer()
        NotificationService.shared.cancelRestTimerNotification()
        updateLiveActivity()
        endRestBackgroundTask()
    }
    
    func skipRestTimer() {
        cancelRestTimer()
    }
    
    private func handleRestTimerExpired() {
        updateLiveActivity()
        endRestBackgroundTask()
    }
    
    private func endRestBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        timer.formatTime(interval)
    }
}
