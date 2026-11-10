import SwiftUI
import UIKit

/// Isolated timer state for an active workout.
/// Uses start/target timestamps so SwiftUI's native `Text(timerInterval:)` can
/// animate ticks inside CoreAnimation without triggering per-second ViewModel or SwiftUI redraws.
@Observable
final class WorkoutTimerViewModel {
    // Workout duration state
    var timerActive = false
    var accumulatedTime: TimeInterval = 0
    var currentSegmentStartTime: Date?
    
    // Rest timer state
    var restTimerActive = false
    var restTimerPaused = false
    var restTargetTime: Date?
    var restTimeRemainingWhenPaused: TimeInterval = 0
    var totalRestDuration: TimeInterval = 0
    
    /// Called on main thread when the active rest timer reaches 0:00.
    var onRestTimerExpired: (() -> Void)?
    
    private var restCompletionTimer: Timer?
    private var foregroundObserver: NSObjectProtocol?
    
    private let restTargetTimeKey = "activeRestTargetTime"
    private let restDurationKey = "activeRestDuration"
    
    init() {
        restorePersistedRestTimer()
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncRestTimerOnForeground()
        }
    }
    
    deinit {
        restCompletionTimer?.invalidate()
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Computed Timestamps & Durations
    
    /// Anchor date such that `Date().timeIntervalSince(elapsedAnchorDate)` equals total elapsed workout time.
    var elapsedAnchorDate: Date? {
        currentSegmentStartTime?.addingTimeInterval(-accumulatedTime)
    }
    
    var currentElapsedTime: TimeInterval {
        if timerActive, let start = currentSegmentStartTime {
            return accumulatedTime + Date().timeIntervalSince(start)
        }
        return accumulatedTime
    }
    
    var currentRestRemaining: TimeInterval {
        if restTimerPaused || !timerActive {
            return max(0, restTimeRemainingWhenPaused)
        }
        if let target = restTargetTime {
            return max(0, target.timeIntervalSince(Date()))
        }
        return 0
    }
    
    // MARK: - Controls
    
    func start() {
        if currentSegmentStartTime == nil {
            currentSegmentStartTime = Date()
        }
        timerActive = true
        if restTimerActive && !restTimerPaused, let target = restTargetTime {
            let remaining = target.timeIntervalSince(Date())
            if remaining > 0 {
                scheduleRestCompletionTimer(after: remaining)
            } else {
                expireRestTimer(notify: false)
            }
        }
    }
    
    func pause() {
        if timerActive, let start = currentSegmentStartTime {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        timerActive = false
        currentSegmentStartTime = nil
        
        if restTimerActive && !restTimerPaused {
            restTimeRemainingWhenPaused = max(0, restTargetTime?.timeIntervalSince(Date()) ?? 0)
            restTimerPaused = true
            restTargetTime = nil
            cancelRestCompletionTimer()
        }
    }
    
    func resume() {
        currentSegmentStartTime = Date()
        timerActive = true
        
        if restTimerActive && restTimerPaused {
            let remaining = restTimeRemainingWhenPaused
            restTimerPaused = false
            if remaining > 0 {
                restTargetTime = Date().addingTimeInterval(remaining)
                scheduleRestCompletionTimer(after: remaining)
            } else {
                expireRestTimer(notify: true)
            }
        }
    }
    
    func startRestTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        let target = Date().addingTimeInterval(duration)
        totalRestDuration = duration
        restTimeRemainingWhenPaused = duration
        restTargetTime = target
        restTimerActive = true
        restTimerPaused = false
        
        UserDefaults.standard.set(target, forKey: restTargetTimeKey)
        UserDefaults.standard.set(duration, forKey: restDurationKey)
        
        scheduleRestCompletionTimer(after: duration)
    }
    
    func cancelRestTimer() {
        cancelRestCompletionTimer()
        restTimerActive = false
        restTimerPaused = false
        restTimeRemainingWhenPaused = 0
        restTargetTime = nil
        
        UserDefaults.standard.removeObject(forKey: restTargetTimeKey)
        UserDefaults.standard.removeObject(forKey: restDurationKey)
    }
    
    func finishAll() {
        cancelRestTimer()
        timerActive = false
        currentSegmentStartTime = nil
    }
    
    // MARK: - One-Shot Completion Scheduling (No 1s Polling!)
    
    private func scheduleRestCompletionTimer(after delay: TimeInterval) {
        cancelRestCompletionTimer()
        guard delay > 0 else {
            expireRestTimer(notify: true)
            return
        }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.expireRestTimer(notify: true)
        }
        RunLoop.main.add(timer, forMode: .common)
        restCompletionTimer = timer
    }
    
    private func cancelRestCompletionTimer() {
        restCompletionTimer?.invalidate()
        restCompletionTimer = nil
    }
    
    private func expireRestTimer(notify: Bool) {
        cancelRestCompletionTimer()
        let wasActive = restTimerActive
        restTimerActive = false
        restTimerPaused = false
        restTimeRemainingWhenPaused = 0
        restTargetTime = nil
        
        UserDefaults.standard.removeObject(forKey: restTargetTimeKey)
        UserDefaults.standard.removeObject(forKey: restDurationKey)
        
        if notify && wasActive {
            onRestTimerExpired?()
        }
    }
    
    private func restorePersistedRestTimer() {
        if let targetTime = UserDefaults.standard.object(forKey: restTargetTimeKey) as? Date,
           let duration = UserDefaults.standard.object(forKey: restDurationKey) as? TimeInterval {
            let remaining = targetTime.timeIntervalSince(Date())
            if remaining > 0 {
                self.restTargetTime = targetTime
                self.totalRestDuration = duration
                self.restTimeRemainingWhenPaused = remaining
                self.restTimerActive = true
                scheduleRestCompletionTimer(after: remaining)
            } else {
                UserDefaults.standard.removeObject(forKey: restTargetTimeKey)
                UserDefaults.standard.removeObject(forKey: restDurationKey)
            }
        }
    }
    
    private func syncRestTimerOnForeground() {
        guard restTimerActive && !restTimerPaused, let target = restTargetTime else { return }
        let remaining = target.timeIntervalSince(Date())
        if remaining <= 0 {
            expireRestTimer(notify: true)
        } else {
            scheduleRestCompletionTimer(after: remaining)
        }
    }
    
    // MARK: - Formatting
    
    func formatTime(_ interval: TimeInterval) -> String {
        let clamped = max(0, Int(interval))
        let hours = clamped / 3600
        let minutes = (clamped / 60) % 60
        let seconds = clamped % 60
        if hours > 0 {
            return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
        }
        return String(format: "%02i:%02i", minutes, seconds)
    }
}
