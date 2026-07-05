import SwiftUI
import SwiftData

@Observable
class WorkoutSessionViewModel {
    // Timer State
    var elapsedTime: TimeInterval = 0
    var accumulatedTime: TimeInterval = 0
    var currentSegmentStartTime: Date?
    var timerActive = false
    
    // Rest Timer State
    var restTimeRemaining: TimeInterval = 0
    var restTargetTime: Date?
    var restTimerActive = false
    var restTimerPaused = false
    var totalRestDuration: TimeInterval = 0
    
    // UI State
    var currentTimeString: String = ""
    
    private var timer: Timer?
    private var restTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private let restTargetTimeKey = "activeRestTargetTime"
    private let restDurationKey = "activeRestDuration"
    
    init() {
        if let targetTime = UserDefaults.standard.object(forKey: restTargetTimeKey) as? Date,
           let duration = UserDefaults.standard.object(forKey: restDurationKey) as? TimeInterval {
            if targetTime > Date() {
                self.restTargetTime = targetTime
                self.totalRestDuration = duration
                self.restTimeRemaining = targetTime.timeIntervalSince(Date())
                self.restTimerActive = true
            } else {
                UserDefaults.standard.removeObject(forKey: restTargetTimeKey)
                UserDefaults.standard.removeObject(forKey: restDurationKey)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTimes()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Cached formatter – DateFormatter is expensive to create; reuse across timer ticks
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    func startWorkout() {
        if currentSegmentStartTime == nil {
            currentSegmentStartTime = Date()
        }
        timerActive = true
        startTimers()
        
        if let session = WorkoutManager.shared.activeSession {
            LiveActivityManager.shared.startWorkoutActivity(
                workoutName: session.plan?.name ?? "Freies Training",
                startDate: currentSegmentStartTime ?? Date(),
                accumulatedTime: self.accumulatedTime,
                isRestTimerActive: self.restTimerActive,
                restTargetTime: self.restTargetTime
            )
        }
    }
    
    private func updateLiveActivity() {
        LiveActivityManager.shared.updateWorkoutActivity(
            isPaused: !timerActive,
            accumulatedTime: accumulatedTime,
            lastStartTime: currentSegmentStartTime,
            isRestTimerActive: restTimerActive,
            restTargetTime: restTargetTime
        )
    }
    
    func pauseWorkout() {
        if timerActive, let start = currentSegmentStartTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        timerActive = false
        currentSegmentStartTime = nil
        stopTimers()
        
        if restTimerActive && !restTimerPaused {
            restTimerPaused = true
            restTargetTime = nil
            NotificationService.shared.cancelRestTimerNotification()
        }
        
        updateLiveActivity()
    }
    
    func resumeWorkout() {
        currentSegmentStartTime = Date()
        timerActive = true
        startTimers()
        
        if restTimerActive && restTimerPaused {
            restTimerPaused = false
            restTargetTime = Date().addingTimeInterval(restTimeRemaining)
            NotificationService.shared.scheduleRestTimerNotification(duration: restTimeRemaining)
        }
        
        updateLiveActivity()
    }
    
    func finishWorkout() {
        stopTimers()
        cancelRestTimer()
        
        LiveActivityManager.shared.endWorkoutActivity()
    }
    
    // MARK: - Rest Timer
    func startRestTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        restTimeRemaining = duration
        totalRestDuration = duration
        restTargetTime = Date().addingTimeInterval(duration)
        restTimerActive = true
        restTimerPaused = false
        
        UserDefaults.standard.set(restTargetTime, forKey: restTargetTimeKey)
        UserDefaults.standard.set(totalRestDuration, forKey: restDurationKey)
        
        NotificationService.shared.scheduleRestTimerNotification(duration: duration)
        updateLiveActivity()
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "RestTimer") { [weak self] in
            guard let self = self else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
    }
    

    func cancelRestTimer() {
        restTimerActive = false
        restTimerPaused = false
        restTimeRemaining = 0
        restTargetTime = nil
        
        UserDefaults.standard.removeObject(forKey: restTargetTimeKey)
        UserDefaults.standard.removeObject(forKey: restDurationKey)
        
        NotificationService.shared.cancelRestTimerNotification()
        updateLiveActivity()
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func skipRestTimer() {
        cancelRestTimer()
    }
    
    // MARK: - Internal Timers
    private func startTimers() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateTimes()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }
    
    private func stopTimers() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimes() {
        // Workout Duration
        if timerActive, let start = currentSegmentStartTime {
            elapsedTime = accumulatedTime + Date().timeIntervalSince(start)
        }
        
        // Real Time Header
        currentTimeString = WorkoutSessionViewModel.timeFormatter.string(from: Date())
        
        // Rest Timer
        if restTimerActive && !restTimerPaused {
            if let target = restTargetTime {
                let remaining = target.timeIntervalSince(Date())
                if remaining > 0 {
                    restTimeRemaining = remaining
                } else {
                    let wasActive = restTimerActive
                    restTimerActive = false
                    restTimeRemaining = 0
                    
                    if wasActive {
                        updateLiveActivity()
                    }
                }
            }
        }
    }
    
    // MARK: - Formatters
    func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
        }
        return String(format: "%02i:%02i", minutes, seconds)
    }
}
