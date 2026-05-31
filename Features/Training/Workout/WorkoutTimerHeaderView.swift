import SwiftUI

struct WorkoutTimerHeaderView: View {
    @Bindable var viewModel: WorkoutSessionViewModel
    let planName: String?
    
    // Timer setting bindings for the menu
    @AppStorage("timerFav1") private var timerFav1: Int = 60
    @AppStorage("timerFav2") private var timerFav2: Int = 90
    @AppStorage("timerFav3") private var timerFav3: Int = 120
    
    // Action to show custom timer alert
    var onShowCustomTimer: () -> Void
    
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
                        .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
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
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            // Rest Timer Banner (Slides down when active)
            if viewModel.restTimerActive {
                Button(action: {
                    // Tap to skip
                    viewModel.skipRestTimer()
                }) {
                    ZStack(alignment: .leading) {
                        // Background Bar
                        Rectangle()
                            .fill(Color.backgroundCard)
                        
                        // Progress Fill
                        GeometryReader { geometry in
                            let progress = viewModel.totalRestDuration > 0 ? (viewModel.restTimeRemaining / viewModel.totalRestDuration) : 0
                            Rectangle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                                .animation(.linear(duration: 1.0), value: progress)
                        }
                        
                        HStack {
                            Image(systemName: "timer")
                            Text("Pause")
                            Spacer()
                            Text(viewModel.formatTime(viewModel.restTimeRemaining))
                                .font(.title.bold().monospacedDigit())
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal)
                    }
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
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
        WorkoutTimerHeaderView(viewModel: vm, planName: "Push Day", onShowCustomTimer: {})
        Spacer()
    }
}
