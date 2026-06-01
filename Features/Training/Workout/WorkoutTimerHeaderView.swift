import SwiftUI

struct WorkoutTimerHeaderView: View {
    @Bindable var viewModel: WorkoutSessionViewModel
    let planName: String?
    
    // Timer setting bindings for the menu
    @AppStorage("timerFav1") private var timerFav1: Int = 60
    @AppStorage("timerFav2") private var timerFav2: Int = 90
    @AppStorage("timerFav3") private var timerFav3: Int = 120
    
    // Actions
    var onShowCustomTimer: () -> Void
    var onSkipRestTimer: () -> Void
    var onMinimize: (() -> Void)? = nil
    
    private var cardHeight: CGFloat {
        if !viewModel.timerActive {
            return viewModel.restTimerActive ? 195 : 205
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
                            if viewModel.timerActive {
                                viewModel.pauseWorkout()
                            } else {
                                viewModel.resumeWorkout()
                            }
                        }
                    }) {
                        Image(systemName: viewModel.timerActive ? "pause.fill" : "play.fill")
                            .font(.title3.bold())
                            .foregroundColor(viewModel.timerActive ? .orange : .green)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(.top, 4)
                }
                
                // Centered content
                VStack(spacing: viewModel.restTimerActive ? 2 : 8) {
                    Text(planName ?? "Freies Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.system(size: viewModel.restTimerActive ? 32 : 76, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundColor(.primary)
                    
                    if !viewModel.timerActive {
                        Text("WORKOUT PAUSIERT")
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
            }
            .padding(.horizontal)
            .padding(.top, viewModel.restTimerActive ? 16 : 28)
            .padding(.bottom, viewModel.restTimerActive ? 8 : 16)
            .frame(maxHeight: .infinity, alignment: .top)
            
            // Rest Timer Banner (Slides down when active)
            if viewModel.restTimerActive {
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
                            if viewModel.restTimerPaused {
                                Text("Satzpause angehalten")
                                    .font(.caption)
                                    .textCase(.uppercase)
                                    .foregroundColor(.white.opacity(0.9))
                            } else {
                                Text("SATZPAUSE")
                                    .font(.caption)
                                    .textCase(.uppercase)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            Text(viewModel.formatTime(viewModel.restTimeRemaining))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.restTimerActive)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.restTimerActive {
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
}

#Preview {
    let vm = WorkoutSessionViewModel()
    vm.elapsedTime = 3600 + 45 * 60 + 30 // 1h 45m 30s
    vm.startRestTimer(duration: 90)
    vm.restTimeRemaining = 45
    return VStack {
        WorkoutTimerHeaderView(viewModel: vm, planName: "Push Day", onShowCustomTimer: {}, onSkipRestTimer: {})
        Spacer()
    }
}
