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
                
                // Manual Timer Start Menu
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
                            .font(.title2)
                            .foregroundColor(.brand)
                            .padding(12)
                            .background(Color.brand.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                
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
                    // Background Bar (Dark Gray for contrast with white text)
                    Rectangle()
                        .fill(Color(white: 0.15))
                    
                    // Progress Fill (Green)
                    GeometryReader { geometry in
                        let progress = viewModel.totalRestDuration > 0 ? (viewModel.restTimeRemaining / viewModel.totalRestDuration) : 0
                        Rectangle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                            .animation(.linear(duration: 1.0), value: progress)
                    }
                    
                    HStack(spacing: 16) {
                        // Skip/Close Button (Swapped to the left)
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
                        
                        // Pause/Play Button (Swapped to the right)
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
            
            Divider()
        }
        .background(.ultraThinMaterial)
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
