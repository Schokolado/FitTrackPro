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
    var onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Header (Always visible)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(planName ?? "Freies Workout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.system(size: 48, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundColor(.primary)
                }
                Spacer()
                
                // Beenden Button
                Button("Beenden") {
                    onFinish()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.brand)
                .clipShape(Capsule())
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            // Rest Timer Banner (Slides down when active)
            if viewModel.restTimerActive {
                ZStack(alignment: .leading) {
                    // Background Bar (Solid Green)
                    Rectangle()
                        .fill(Color.green)
                    
                    HStack(spacing: 16) {
                        // Skip/Close Button (Left)
                        Button(action: {
                            viewModel.skipRestTimer()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title3.bold())
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Text(viewModel.restTimerPaused ? "Pausiert" : "Pause")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(viewModel.formatTime(viewModel.restTimeRemaining))
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        
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
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Divider removed, replaced by shadow below
        }
        .background(Color.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        WorkoutTimerHeaderView(viewModel: vm, planName: "Push Day", onShowCustomTimer: {}, onFinish: {})
        Spacer()
    }
}
