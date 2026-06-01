import SwiftUI

struct WorkoutMiniPlayerView: View {
    let viewModel: WorkoutSessionViewModel
    let planName: String?
    let onTap: () -> Void
    
    @State private var showingCancelTimerAlert = false
    @State private var showingCustomTimerAlert = false
    @State private var customTimerSeconds = ""
    
    @AppStorage("timerFav1") private var timerFav1 = 30
    @AppStorage("timerFav2") private var timerFav2 = 60
    @AppStorage("timerFav3") private var timerFav3 = 90
    
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
                HStack(spacing: 6) {
                    Text(planName ?? "Freies Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !viewModel.timerActive {
                        Text("PAUSIERT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                HStack {
                    Text(viewModel.formatTime(viewModel.elapsedTime))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.brand)
                    
                    if viewModel.restTimerActive {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.restTimerPaused ? "Angehalten: \(viewModel.formatTime(viewModel.restTimeRemaining))" : "Pause: \(viewModel.formatTime(viewModel.restTimeRemaining))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                // Start Rest Timer Menu
                if !viewModel.restTimerActive {
                    Menu {
                        Button("\(timerFav1) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav1)) }
                        Button("\(timerFav2) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav2)) }
                        Button("\(timerFav3) Sek") { viewModel.startRestTimer(duration: TimeInterval(timerFav3)) }
                        Divider()
                        Button("Individuell...") {
                            showingCustomTimerAlert = true
                        }
                    } label: {
                        Image(systemName: "timer")
                            .font(.system(size: 26))
                            .foregroundColor(.green)
                    }
                } else {
                    // Cancel Rest Timer Button
                    Button(action: {
                        showingCancelTimerAlert = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Play/Pause button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if viewModel.timerActive {
                            viewModel.pauseWorkout()
                        } else {
                            viewModel.resumeWorkout()
                        }
                    }
                }) {
                    Image(systemName: viewModel.timerActive ? "pause.circle" : "play.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
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
        .confirmationDialog("Satzpause", isPresented: $showingCancelTimerAlert, titleVisibility: .visible) {
            if viewModel.restTimerPaused {
                Button("Fortsetzen") {
                    viewModel.toggleRestTimerPause()
                }
            } else {
                Button("Pausieren") {
                    viewModel.toggleRestTimerPause()
                }
            }
            Button("Beenden", role: .destructive) {
                viewModel.cancelRestTimer()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Was möchtest du mit der Satzpause machen?")
        }
        .alert("Eigener Timer", isPresented: $showingCustomTimerAlert) {
            TextField("Sekunden", text: $customTimerSeconds)
                .keyboardType(.numberPad)
            Button("Starten") {
                if let seconds = Int(customTimerSeconds), seconds > 0 {
                    viewModel.startRestTimer(duration: TimeInterval(seconds))
                }
                customTimerSeconds = ""
            }
            Button("Abbrechen", role: .cancel) {
                customTimerSeconds = ""
            }
        } message: {
            Text("Gib die gewünschte Pausenzeit in Sekunden ein.")
        }
    }
}
