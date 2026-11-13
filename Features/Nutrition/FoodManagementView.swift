import SwiftUI
import SwiftData

struct FoodManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedFood.createdAt, order: .reverse) private var savedFoods: [SavedFood]
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    
    @State private var selectedTab = 0 // 0 = Lebensmittel, 1 = Rezepte
    @State private var searchText = ""
    
    // Navigation State
    @State private var showSavedFoodForm = false
    @State private var showRecipeBuilder = false
    @State private var foodToEdit: SavedFood?
    @State private var recipeToEdit: Recipe?
    
    private var filteredSavedFoods: [SavedFood] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedFoods
        }
        return savedFoods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredRecipes: [Recipe] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return recipes
        }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $selectedTab) {
                Text("Eigene Lebensmittel").tag(0)
                Text("Eigene Rezepte").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                savedFoodsList
            } else {
                recipesList
            }
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Verwaltung")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: selectedTab == 0 ? "Lebensmittel suchen..." : "Rezepte suchen...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if selectedTab == 0 {
                        showSavedFoodForm = true
                    } else {
                        showRecipeBuilder = true
                    }
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showSavedFoodForm) {
            SavedFoodFormView()
        }
        .sheet(isPresented: $showRecipeBuilder) {
            RecipeBuilderView()
        }
        .sheet(item: $foodToEdit) { food in
            SavedFoodFormView(foodToEdit: food)
        }
        .sheet(item: $recipeToEdit) { recipe in
            RecipeBuilderView(recipeToEdit: recipe)
        }
    }
    
    @ViewBuilder
    private var savedFoodsList: some View {
        List {
            if filteredSavedFoods.isEmpty {
                Text(searchText.isEmpty ? "Noch keine eigenen Lebensmittel gespeichert." : "Keine Lebensmittel für „\(searchText)“ gefunden.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredSavedFoods) { food in
                    Button(action: {
                        foodToEdit = food
                    }) {
                        VStack(alignment: .leading) {
                            Text(food.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(Int(food.caloriesPer100g)) kcal / 100g")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(food)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var recipesList: some View {
        List {
            if filteredRecipes.isEmpty {
                Text(searchText.isEmpty ? "Noch keine eigenen Rezepte erstellt." : "Keine Rezepte für „\(searchText)“ gefunden.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredRecipes) { recipe in
                    Button(action: {
                        recipeToEdit = recipe
                    }) {
                        VStack(alignment: .leading) {
                            Text(recipe.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(Int(recipe.totalCalories)) kcal | \(Int(recipe.portions)) Portion(en)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(recipe)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }
}
