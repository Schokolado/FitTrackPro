import SwiftUI
import SwiftData

struct FoodEntryDetailView: View {
    let entry: FoodEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.healthKitEnabled) private var healthKitEnabled = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                VStack(spacing: Spacing.xs) {
                    Text(entry.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("\(Int(entry.amountGrams)) g")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, Spacing.lg)
                
                // Macros Card
                VStack(spacing: Spacing.md) {
                    Text("Nährwerte")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    macroRow(title: "Kalorien", value: entry.calories, unit: "kcal", color: .brand)
                    Divider()
                    macroRow(title: "Protein", value: entry.proteinGrams, unit: "g", color: .blue)
                    Divider()
                    macroRow(title: "Kohlenhydrate", value: entry.carbsGrams, unit: "g", color: .orange)
                    Divider()
                    macroRow(title: "Fett", value: entry.fatGrams, unit: "g", color: .red)
                }
                .padding()
                .cardStyle()
                
                // Info Card
                VStack(spacing: Spacing.md) {
                    Text("Details")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    infoRow(title: "Mahlzeit", value: entry.mealType.rawValue)
                    Divider()
                    infoRow(title: "Hinzugefügt am", value: entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                    
                    if let note = entry.recipeNote, !note.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rezeptzutaten")
                                .foregroundColor(.secondary)
                            Text(note)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .cardStyle()
                
                // Action Buttons
                VStack(spacing: Spacing.sm) {
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Eintrag bearbeiten")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brand.opacity(0.12))
                        .foregroundColor(.brand)
                        .cornerRadius(12)
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Eintrag löschen")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                }
                .padding(.top, Spacing.md)
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            FoodEntryEditView(entry: entry)
        }
        .alert("Eintrag löschen?", isPresented: $showingDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                if healthKitEnabled {
                    Task {
                        try? await HealthKitService.shared.deleteNutrition(entry: entry)
                    }
                }
                modelContext.delete(entry)
                dismiss()
            }
        } message: {
            Text("Möchtest du dieses Lebensmittel wirklich entfernen?")
        }
    }
    
    private func macroRow(title: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .fontWeight(.medium)
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
