import SwiftUI

struct WorkoutTimerHeaderView: View {
    let viewModel: WorkoutSessionViewModel
    let planName: String?
    var hasNotes: Bool = false
    
    private var timer: WorkoutTimerViewModel {
        viewModel.timer
    }
    
    // Timer setting bindings for the menu
    @AppStorage("timerFav1") private var timerFav1: Int = 30
    @AppStorage("timerFav2") private var timerFav2: Int = 60
    @AppStorage("timerFav3") private var timerFav3: Int = 90
    
    // Actions
    var onShowCustomTimer: () -> Void
    var onSkipRestTimer: () -> Void
    var onShowNotes: (() -> Void)? = nil
    var onMinimize: (() -> Void)? = nil
    
    private var cardHeight: CGFloat {
        if !timer.timerActive {
            return timer.restTimerActive ? 195 : 205
        }
        return 170
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Header (Always visible)
            ZStack(alignment: .topLeading) {
                if let onMinimize = onMinimize {
                    Button(action: onMinimize) {
                        Image(systemName: "chevron.down")
                            .font(.title3.bold())
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.top, 4)
                }
                
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if timer.timerActive {
                                viewModel.pauseWorkout()
                            } else {
                                viewModel.resumeWorkout()
                            }
                        }
                    }) {
                        Image(systemName: timer.timerActive ? "pause.fill" : "play.fill")
                            .font(.title3.bold())
                            .foregroundColor(timer.timerActive ? .orange : .green)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.top, 4)
                }
                
                // Centered content
                VStack(spacing: timer.restTimerActive ? 2 : 8) {
                    if let onShowNotes = onShowNotes {
                        Button(action: onShowNotes) {
                            HStack(spacing: 6) {
                                Text(planName ?? "Freies Workout")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                if hasNotes {
                                    Image(systemName: "note.text")
                                        .font(.caption)
                                        .foregroundColor(.brand)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(planName ?? "Freies Workout")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            if hasNotes {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.brand)
                            }
                        }
                    }
                    
                    elapsedDurationText
                        .font(.system(size: timer.restTimerActive ? 32 : 76, weight: .heavy, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundColor(.primary)
                    
                    if !timer.timerActive {
                        Text("WORKOUT ANGEHALTEN")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 65) // Prevents text from overlapping the buttons
            }
            .padding(.horizontal)
            .padding(.top, timer.restTimerActive ? 16 : 28)
            .padding(.bottom, timer.restTimerActive ? 8 : 16)
            .frame(maxHeight: .infinity, alignment: .top)
            
            // Rest Timer Banner (Slides down when active)
            if timer.restTimerActive {
                ZStack(alignment: .leading) {
                    // Background Bar (Solid Green)
                    Rectangle()
                        .fill(Color.green)
                    
                    HStack {
                        // Skip/Close Button (Left)
                        Button(action: {
                            onSkipRestTimer()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title3.bold())
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 0) {
                            Text("SATZPAUSE")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundColor(.white.opacity(0.9))
                            restDurationText
                                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        
                        Spacer()
                        
                        // Invisible block to perfectly center the text
                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)
                }
                .frame(height: 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: cardHeight)
        .background(Color.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cardHeight)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timer.restTimerActive)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .overlay(alignment: .bottomTrailing) {
            if !timer.restTimerActive {
                Menu {
                    Button("\(timerFav1) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav1)) }
                    Button("\(timerFav2) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav2)) }
                    Button("\(timerFav3) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav3)) }
                    Divider()
                    Button("Individuell...") {
                        onShowCustomTimer()
                    }
                } label: {
                    Image(systemName: "timer")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 39) // 16 padding + 23 offset
            }
        }
    }
    
    @ViewBuilder
    private var elapsedDurationText: some View {
        if timer.timerActive, let anchor = timer.elapsedAnchorDate {
            let floored = Date(timeIntervalSinceReferenceDate: floor(anchor.timeIntervalSinceReferenceDate))
            let safeAnchor = min(floored, Date())
            Text(timerInterval: safeAnchor...safeAnchor.addingTimeInterval(360000), countsDown: false)
        } else {
            Text(timer.formatTime(timer.accumulatedTime))
        }
    }
    
    @ViewBuilder
    private var restDurationText: some View {
        if timer.restTimerPaused || !timer.timerActive {
            Text(timer.formatTime(timer.currentRestRemaining))
        } else if let target = timer.restTargetTime {
            let flooredTarget = Date(timeIntervalSinceReferenceDate: floor(target.timeIntervalSinceReferenceDate))
            let flooredNow = Date(timeIntervalSinceReferenceDate: floor(Date().timeIntervalSinceReferenceDate))
            let start = min(flooredNow, flooredTarget)
            Text(timerInterval: start...flooredTarget, countsDown: true)
        } else {
            Text("00:00")
        }
    }
}

#Preview {
    let vm = WorkoutSessionViewModel()
    vm.accumulatedTime = 3600 + 45 * 60 + 30 // 1h 45m 30s
    vm.startWorkout()
    vm.startRestTimer(duration: 90)
    return VStack {
        WorkoutTimerHeaderView(viewModel: vm, planName: "Push Day", onShowCustomTimer: {}, onSkipRestTimer: {})
        Spacer()
    }
}
