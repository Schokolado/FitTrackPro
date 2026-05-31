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
    var restTimerActive = false
    var restTimerPaused = false
    var totalRestDuration: TimeInterval = 0
    
    // UI State
    var currentTimeString: String = ""
    
    private var timer: Timer?
    private var restTimer: Timer?
    
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
    }
    
    func pauseWorkout() {
        if timerActive, let start = currentSegmentStartTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        timerActive = false
        currentSegmentStartTime = nil
        stopTimers()
    }
    
    func resumeWorkout() {
        currentSegmentStartTime = Date()
        timerActive = true
        startTimers()
    }
    
    func finishWorkout() {
        stopTimers()
        cancelRestTimer()
    }
    
    // MARK: - Rest Timer
    func startRestTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        restTimeRemaining = duration
        totalRestDuration = duration
        restTimerActive = true
        restTimerPaused = false
        NotificationService.shared.scheduleRestTimerNotification(duration: duration)
    }
    
    func toggleRestTimerPause() {
        restTimerPaused.toggle()
        if restTimerPaused {
            NotificationService.shared.cancelRestTimerNotification()
        } else {
            NotificationService.shared.scheduleRestTimerNotification(duration: restTimeRemaining)
        }
    }
    
    func cancelRestTimer() {
        restTimerActive = false
        restTimerPaused = false
        restTimeRemaining = 0
        NotificationService.shared.cancelRestTimerNotification()
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
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                restTimerActive = false
                // Auto-cancel notification logic triggers anyway since time passed
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
