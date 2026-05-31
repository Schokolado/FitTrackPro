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
        Group {
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
            .safeAreaInset(edge: .top) {
                // Header Card
                VStack(spacing: 16) {
                    // Category Filter Dropdown
                    HStack {
                        Text("Kategorie")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("Kategorie", selection: $viewModel.selectedCategory) {
                            Text("Alle").tag(String?.none)
                            ForEach(availableCategories, id: \.self) { category in
                                Text(category).tag(String?(category))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.brand)
                    }
                    
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
                    .padding(12)
                    .background(Color.backgroundPrimary)
                    .cornerRadius(12)
                }
                .padding(20)
                .background(Color.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
                .background(
                    VStack(spacing: 0) {
                        Color.backgroundPrimary
                        LinearGradient(
                            colors: [Color.backgroundPrimary, Color.backgroundPrimary.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 32)
                    }
                    .ignoresSafeArea(.container, edges: .top)
                )
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

