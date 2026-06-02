import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weightEntries: [WeightEntry]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NavigationLink(destination: WeightTrackerView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Körpergewicht")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let latestWeight = weightEntries.first {
                                    Text("\(latestWeight.weightKg, specifier: "%.1f") kg")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("-- kg")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.backgroundSecondary)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
