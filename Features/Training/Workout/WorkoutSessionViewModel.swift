import SwiftUI
import SwiftData

// MARK: - WorkoutSessionViewModel

@Observable
class WorkoutSessionViewModel {

    // MARK: - Workout Timer State

    var startTime: Date?
    var elapsedTime: TimeInterval = 0
    var timerActive = false

    // MARK: - Rest Timer State

    var restTimeRemaining: TimeInterval = 0
    var restTimerActive = false
    var totalRestDuration: TimeInterval = 0

    // MARK: - UI State

    var currentTimeString: String = ""

    // MARK: - Private

    private var timer: Timer?

    /// Shared formatter – created once, reused every timer tick to avoid repeated allocations.
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    // MARK: - Workout Control

    func startWorkout() {
        startTime = Date()
        timerActive = true
        startTimer()
    }

    func pauseWorkout() {
        timerActive = false
        stopTimer()
    }

    func resumeWorkout() {
        timerActive = true
        startTimer()
    }

    func finishWorkout() {
        stopTimer()
        cancelRestTimer()
    }

    // MARK: - Rest Timer

    func startRestTimer(duration: TimeInterval) {
        restTimeRemaining = duration
        totalRestDuration = duration
        restTimerActive = true
        NotificationService.shared.scheduleRestTimerNotification(duration: duration)
    }

    func cancelRestTimer() {
        restTimerActive = false
        restTimeRemaining = 0
        NotificationService.shared.cancelRestTimerNotification()
    }

    func skipRestTimer() {
        cancelRestTimer()
    }

    // MARK: - Formatting

    func formatTime(_ interval: TimeInterval) -> String {
        let hours   = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
        }
        return String(format: "%02i:%02i", minutes, seconds)
    }

    // MARK: - Private Timer Helpers

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if timerActive, let start = startTime {
            elapsedTime = Date().timeIntervalSince(start)
        }

        currentTimeString = timeFormatter.string(from: Date())

        if restTimerActive {
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                restTimerActive = false
            }
        }
    }
}
