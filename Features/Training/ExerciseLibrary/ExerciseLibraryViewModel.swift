import SwiftUI
import SwiftData

@Observable
class ExerciseLibraryViewModel {
    var searchText: String = ""
    var selectedCategory: String? = nil
    
    // Filtering logic to be applied on the queried exercises in the view
    func filterExercises(_ exercises: [Exercise]) -> [Exercise] {
        exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || exercise.category == selectedCategory
            return matchesSearch && matchesCategory
        }
        .sorted { ex1, ex2 in
            if ex1.category != ex2.category {
                return ex1.category < ex2.category
            }
            let s1 = ex1.sortOrder == 0 ? 999 : ex1.sortOrder
            let s2 = ex2.sortOrder == 0 ? 999 : ex2.sortOrder
            if s1 != s2 {
                return s1 < s2
            }
            return ex1.name < ex2.name
        }
    }
}
