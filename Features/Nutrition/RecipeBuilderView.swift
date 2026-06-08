import SwiftUI
import SwiftData

struct RecipeBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var recipeToEdit: Recipe?
    
    @State private var recipeName: String = ""
    @State private var portions: Double = 1.0
    @State private var ingredients: [RecipeIngredient] = []
    
    @State private var showIngredientSearch = false
    
    // Computed totals
    private var totalCalories: Double { ingredients.reduce(0) { $0 + $1.totalCalories } }
    private var totalProtein: Double { ingredients.reduce(0) { $0 + $1.totalProtein } }
    private var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.totalCarbs } }
    private var totalFat: Double { ingredients.reduce(0) { $0 + $1.totalFat } }
    private var totalGrams: Double { ingredients.reduce(0) { $0 + $1.amountGrams } }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rezept-Details")) {
                    TextField("Name (z.B. Protein-Pancakes)", text: $recipeName)
                    HStack {
                        Text("Portionen")
                        Spacer()
                        TextField("1.0", value: $portions, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Zutaten")) {
                    if ingredients.isEmpty {
                        Text("Noch keine Zutaten hinzugefügt.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(ingredients) { ingredient in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(ingredient.name)
                                        .font(.headline)
                                    Text("\(ingredient.amountGrams, specifier: "%.0f")g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(ingredient.totalCalories, specifier: "%.0f") kcal")
                            }
                        }
                        .onDelete(perform: deleteIngredient)
                    }
                    
                    Button(action: {
                        showIngredientSearch = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Zutat hinzufügen")
                        }
                    }
                }
                
                Section(header: Text("Gesamtnährwerte")) {
                    HStack {
                        Text("Gewicht gesamt")
                        Spacer()
                        Text("\(totalGrams, specifier: "%.0f") g")
                    }
                    HStack {
                        Text("Kalorien")
                        Spacer()
                        Text("\(totalCalories, specifier: "%.0f") kcal")
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(totalProtein, specifier: "%.1f") g")
                    }
                    HStack {
                        Text("Kohlenhydrate")
                        Spacer()
                        Text("\(totalCarbs, specifier: "%.1f") g")
                    }
                    HStack {
                        Text("Fett")
                        Spacer()
                        Text("\(totalFat, specifier: "%.1f") g")
                    }
                }
                
                if portions > 1 {
                    Section(header: Text("Pro Portion")) {
                        HStack {
                            Text("Kalorien")
                            Spacer()
                            Text("\(totalCalories / portions, specifier: "%.0f") kcal")
                        }
                    }
                }
            }
            .navigationTitle(recipeToEdit == nil ? "Neues Rezept" : "Rezept bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveRecipe()
                    }
                    .disabled(recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ingredients.isEmpty)
                }
            }
            .sheet(isPresented: $showIngredientSearch) {
                // Here we re-use FoodSearchView, but we pass a completion handler to add it to ingredients
                FoodSearchView(mealType: nil, onIngredientSelected: { name, cal, pro, carb, fat, amount in
                    let newIng = RecipeIngredient(name: name, caloriesPer100g: cal, proteinPer100g: pro, carbsPer100g: carb, fatPer100g: fat, amountGrams: amount)
                    ingredients.append(newIng)
                })
            }
            .onAppear {
                if let recipe = recipeToEdit {
                    recipeName = recipe.name
                    portions = recipe.portions
                    ingredients = recipe.ingredients ?? []
                }
            }
        }
    }
    
    private func deleteIngredient(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }
    
    private func saveRecipe() {
        if let recipe = recipeToEdit {
            recipe.name = recipeName
            recipe.portions = portions
            
            let oldIngredients = recipe.ingredients ?? []
            for old in oldIngredients {
                if !ingredients.contains(where: { $0.id == old.id }) {
                    modelContext.delete(old)
                }
            }
            recipe.ingredients = ingredients
            for ingredient in ingredients {
                ingredient.recipe = recipe
                if ingredient.modelContext == nil {
                    modelContext.insert(ingredient)
                }
            }
        } else {
            let recipe = Recipe(name: recipeName, portions: portions)
            modelContext.insert(recipe)
            
            for ingredient in ingredients {
                ingredient.recipe = recipe
                modelContext.insert(ingredient)
            }
        }
        
        dismiss()
    }
}
