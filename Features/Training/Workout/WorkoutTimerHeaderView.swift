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
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Header (Always visible)
            ZStack {
                // Centered content
                VStack(spacing: viewModel.restTimerActive ? 2 : 8) {
                    Text(planName ?? "Freies Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.system(size: viewModel.restTimerActive ? 56 : 76, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, viewModel.restTimerActive ? 12 : 16)
            .frame(maxHeight: .infinity)
            
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
                                Text("Pausiert")
                                    .font(.caption)
                                    .textCase(.uppercase)
                                    .foregroundColor(.white.opacity(0.9))
                            } else {
                                Text("Pause")
                                    .font(.caption)
                                    .textCase(.uppercase)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            Text(viewModel.formatTime(viewModel.restTimeRemaining))
                                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        
                        Spacer()
                        
                        // Pause/Play Button (Right)
                        Button(action: {
                            viewModel.toggleRestTimerPause()
                        }) {
                            Image(systemName: viewModel.restTimerPaused ? "play.fill" : "pause.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)
                }
                .frame(height: 70)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 170)
        .background(Color.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.restTimerActive)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 16)
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
