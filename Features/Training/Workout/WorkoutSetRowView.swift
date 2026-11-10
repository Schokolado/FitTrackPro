import SwiftUI
import SwiftData

struct WorkoutSetRowView: View {
    @Bindable var workoutSet: WorkoutSet
    let onComplete: () -> Void
    
    var body: some View {
        let isCardio = workoutSet.exercise?.usesLevelInput == true
        let isTimeBased = workoutSet.exercise?.usesTimeInput == true
        let durationUnit = workoutSet.exercise?.effectiveTimeUnit ?? "Sek"
        let showsSecondaryInput = workoutSet.exercise?.showsSecondaryInput ?? true
        
        HStack {
            // Set Number
            Text("\(workoutSet.setNumber)")
                .font(.headline)
                .frame(width: 30)
                .foregroundColor(workoutSet.isCompleted ? .secondary : .primary)
            
            if showsSecondaryInput {
                Spacer()
                
                // Weight or Level Input
                HStack(spacing: 4) {
                    TextField("-", value: $workoutSet.actualWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(8)
                        .background(Color.backgroundSecondary)
                        .cornerRadius(8)
                    Text(isCardio ? "Lvl" : "kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(workoutSet.isCompleted)
            }
            
            Spacer()
            
            // Reps / Duration Input
            HStack(spacing: 4) {
                TextField("-", value: $workoutSet.actualReps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(8)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(8)
                Text(isTimeBased ? durationUnit : "Wdh")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .disabled(workoutSet.isCompleted)
            
            Spacer()
            
            // Check Button
            Button(action: {
                // Toggle complete
                workoutSet.isCompleted.toggle()
                if workoutSet.isCompleted {
                    // Trigger rest timer
                    onComplete()
                }
            }) {
                Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(workoutSet.isCompleted ? .success : .secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(workoutSet.isCompleted ? 0.6 : 1.0)
    }
}
