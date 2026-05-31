import SwiftUI

struct WorkoutMiniPlayerView: View {
    let viewModel: WorkoutSessionViewModel
    let planName: String?
    let onTap: () -> Void
    
    @State private var showingCancelTimerAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(viewModel.restTimerActive ? Color.green.opacity(0.15) : Color.brand.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: viewModel.restTimerActive ? "timer" : "figure.run")
                    .foregroundColor(viewModel.restTimerActive ? .green : .brand)
                    .font(.system(size: 20))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(planName ?? "Freies Workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if viewModel.restTimerActive {
                    Text("Pause: \(viewModel.formatTime(viewModel.restTimeRemaining))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.green)
                } else {
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.brand)
                }
            }
            
            Spacer()
            
            // Play/Pause button
            Button(action: {
                if viewModel.restTimerActive {
                    showingCancelTimerAlert = true
                } else if viewModel.timerActive {
                    viewModel.pauseWorkout()
                } else {
                    viewModel.resumeWorkout()
                }
            }) {
                Image(systemName: viewModel.restTimerActive ? "xmark.circle.fill" : (viewModel.timerActive ? "pause.circle.fill" : "play.circle.fill"))
                    .font(.system(size: 32))
                    .foregroundColor(.brand)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -4)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onTapGesture {
            onTap()
        }
        .alert("Pause beenden?", isPresented: $showingCancelTimerAlert) {
            Button("Beenden", role: .destructive) {
                viewModel.cancelRestTimer()
            }
            Button("Weiterlaufen lassen", role: .cancel) { }
        } message: {
            Text("Möchtest du die aktuelle Satz-Pause abbrechen?")
        }
    }
}
