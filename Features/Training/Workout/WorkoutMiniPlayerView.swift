import SwiftUI

struct WorkoutMiniPlayerView: View {
    let viewModel: WorkoutSessionViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "figure.run")
                        .foregroundColor(.brand)
                        .font(.system(size: 20))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout aktiv")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.brand)
                }
                
                Spacer()
                
                // Play/Pause button
                Button(action: {
                    if viewModel.timerActive {
                        viewModel.pauseWorkout()
                    } else {
                        viewModel.startWorkout()
                    }
                }) {
                    Image(systemName: viewModel.timerActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.brand)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.backgroundCard)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
