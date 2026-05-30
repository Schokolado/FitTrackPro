import SwiftUI
import SwiftData

struct PlanExerciseRowView: View {
    @Bindable var planExercise: PlanExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(planExercise.exercise?.name ?? "Gelöschte Übung")
                    .font(.headline)
                Spacer()
                if planExercise.supersetGroup != nil {
                    Image(systemName: "link")
                        .foregroundColor(.brandSecondary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Sätze")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(planExercise.targetSets)", value: $planExercise.targetSets, in: 0...20)
                }
                
                VStack(alignment: .leading) {
                    Text("Wdh.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(planExercise.targetReps)", value: $planExercise.targetReps, in: 0...100)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Ziel-Gewicht (kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", value: $planExercise.targetWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }
                
                VStack(alignment: .leading) {
                    Text("Pause (s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper("\(Int(planExercise.restDuration))", value: $planExercise.restDuration, in: 0...300, step: 10)
                }
            }
            
            // Supersatz Toggle
            Toggle(isOn: Binding(
                get: { planExercise.supersetGroup != nil },
                set: { isSuper in
                    // Simple logic: if true, group it with the previous exercise (same group ID)
                    // In a real complex app, you'd select which group to join. For now, simple toggle assigning an ID.
                    if isSuper {
                        planExercise.supersetGroup = 1 // Simplified: just assign group 1 for UI representation
                    } else {
                        planExercise.supersetGroup = nil
                    }
                }
            )) {
                Text("Als Supersatz markieren")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
