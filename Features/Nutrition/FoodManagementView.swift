import SwiftUI
import SwiftData

struct FoodManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedFood.createdAt, order: .reverse) private var savedFoods: [SavedFood]
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    
    @State private var selectedTab = 0 // 0 = Lebensmittel, 1 = Rezepte
    
    // Navigation State
    @State private var showSavedFoodForm = false
    @State private var showRecipeBuilder = false
    
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
    }
    
    private var savedFoodsList: some View {
        List {
            if savedFoods.isEmpty {
                Text("Noch keine eigenen Lebensmittel gespeichert.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(savedFoods) { food in
                    VStack(alignment: .leading) {
                        Text(food.name)
                            .font(.headline)
                        Text("\(Int(food.caloriesPer100g)) kcal / 100g")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(food)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    private var recipesList: some View {
        List {
            if recipes.isEmpty {
                Text("Noch keine eigenen Rezepte erstellt.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(recipes) { recipe in
                    VStack(alignment: .leading) {
                        Text(recipe.name)
                            .font(.headline)
                        Text("\(Int(recipe.totalCalories)) kcal | \(Int(recipe.portions)) Portion(en)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(recipe)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
