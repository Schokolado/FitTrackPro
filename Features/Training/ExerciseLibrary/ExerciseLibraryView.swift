import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    
    private var availableCategories: [String] {
        Array(Set(allExercises.map { $0.category })).sorted()
    }
    
    @State private var viewModel = ExerciseLibraryViewModel()
    @Binding var triggerAddExercise: Bool
    
    var body: some View {
        VStack {
                // Category Filter Dropdown
                HStack {
                    Text("Kategorie:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Kategorie", selection: $viewModel.selectedCategory) {
                        Text("Alle").tag(String?.none)
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(String?(category))
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                
                // Custom Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Übung suchen...", text: $viewModel.searchText)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                List {
                    ForEach(viewModel.filterExercises(allExercises)) { exercise in
                        ZStack {
                            ExerciseCardView(exercise: exercise)
                            
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                EmptyView()
                            }
                            .opacity(0)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteExercises)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Übungen")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $triggerAddExercise) {
                NavigationStack {
                    ExerciseFormView()
                }
            }
            .onAppear {
                SeedDataService.shared.seedExercisesIfNeeded(context: modelContext)
            }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        let filtered = viewModel.filterExercises(allExercises)
        for index in offsets {
            let exercise = filtered[index]
            exercise.deleteCascading(in: modelContext)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brand : Color.backgroundSecondary)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ExerciseCardView: View {
    let exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        HStack(spacing: 16) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [themeManager.color(for: exercise.category).opacity(0.7), themeManager.color(for: exercise.category)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                ExerciseIconView(exercise: exercise, size: 24)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Category Badge
                Text(exercise.category.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.color(for: exercise.category))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.color(for: exercise.category).opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Color(.systemGray3))
                .font(.footnote.weight(.semibold))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
