import Foundation

struct SeedExercise: Codable {
    let name: String
    let category: String
    let defaultRestDuration: Double
    let sortOrder: Int
}

let jsonString = """
[
  { "name": "Bankdrücken (Langhantel)", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 1 },
  { "name": "Bankdrücken (Kurzhantel)", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 2 },
  { "name": "Schrägbankdrücken (Kurzhanteln)", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 3 },
  { "name": "Butterfly (Maschine)", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 4 },
  { "name": "Butterfly (Kurzhantel)", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 5 },
  { "name": "Schrägbank Butterfly (Kurzhantel)", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 6 },
  { "name": "Fliegende am Kabelzug", "category": "Brust", "defaultRestDuration": 90, "sortOrder": 7 },
  { "name": "Liegestütze", "category": "Brust", "defaultRestDuration": 60, "sortOrder": 8 },
  
  { "name": "Kreuzheben", "category": "Rücken", "defaultRestDuration": 120, "sortOrder": 10 },
  { "name": "Klimmzüge", "category": "Rücken", "defaultRestDuration": 90, "sortOrder": 11 },
  { "name": "Latzug", "category": "Rücken", "defaultRestDuration": 90, "sortOrder": 12 },
  { "name": "Latziehen zum Nacken", "category": "Rücken", "defaultRestDuration": 90, "sortOrder": 13 },
  { "name": "Rudern vorgebeugt (Langhantel)", "category": "Rücken", "defaultRestDuration": 90, "sortOrder": 14 },
  { "name": "Rudern sitzend (Kabelzug)", "category": "Rücken", "defaultRestDuration": 90, "sortOrder": 15 },
  
  { "name": "Kniebeugen (Langhantel)", "category": "Beine", "defaultRestDuration": 120, "sortOrder": 20 },
  { "name": "Beinpresse", "category": "Beine", "defaultRestDuration": 120, "sortOrder": 21 },
  { "name": "Beinbeuger (Maschine)", "category": "Beine", "defaultRestDuration": 90, "sortOrder": 22 },
  { "name": "Beinstrecker (Maschine)", "category": "Beine", "defaultRestDuration": 90, "sortOrder": 23 },
  { "name": "Ausfallschritte (Lunges)", "category": "Beine", "defaultRestDuration": 90, "sortOrder": 24 },
  { "name": "Wadenheben", "category": "Beine", "defaultRestDuration": 60, "sortOrder": 25 },
  
  { "name": "Schulterdrücken (Kurzhanteln)", "category": "Schultern", "defaultRestDuration": 90, "sortOrder": 30 },
  { "name": "Military Press (Langhantel)", "category": "Schultern", "defaultRestDuration": 90, "sortOrder": 31 },
  { "name": "Seitheben (Kurzhanteln)", "category": "Schultern", "defaultRestDuration": 60, "sortOrder": 32 },
  { "name": "Face Pulls (Kabelzug)", "category": "Schultern", "defaultRestDuration": 60, "sortOrder": 33 },
  
  { "name": "Bizeps Curls (Kurzhanteln)", "category": "Arme", "defaultRestDuration": 60, "sortOrder": 40 },
  { "name": "Hammer Curls", "category": "Arme", "defaultRestDuration": 60, "sortOrder": 41 },
  { "name": "Trizepsdrücken (Kabelzug)", "category": "Arme", "defaultRestDuration": 60, "sortOrder": 42 },
  { "name": "Dips", "category": "Arme", "defaultRestDuration": 90, "sortOrder": 43 },
  { "name": "French Press (SZ-Stange)", "category": "Arme", "defaultRestDuration": 60, "sortOrder": 44 },
  
  { "name": "Crunches", "category": "Bauch / Core", "defaultRestDuration": 60, "sortOrder": 50 },
  { "name": "Beinheben (hängend)", "category": "Bauch / Core", "defaultRestDuration": 60, "sortOrder": 51 },
  { "name": "Plank (Unterarmstütz)", "category": "Bauch / Core", "defaultRestDuration": 60, "sortOrder": 52 },
  { "name": "Cable Crunches", "category": "Bauch / Core", "defaultRestDuration": 60, "sortOrder": 53 },
  
  { "name": "Laufband", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 60 },
  { "name": "Rudergerät", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 61 },
  { "name": "Fahrrad-Ergometer", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 62 },
  { "name": "Stairmaster", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 63 },
  
  { "name": "Burpees", "category": "Nicht zugeordnet", "defaultRestDuration": 60, "sortOrder": 70 }
]
"""

guard let data = jsonString.data(using: .utf8) else { fatalError("Data error") }
do {
    let _ = try JSONDecoder().decode([SeedExercise].self, from: data)
    print("SUCCESS JSON DE")
} catch {
    print("ERROR DE: \\(error)")
}

let jsonStringEn = """
[
  { "name": "Bench Press (Barbell)", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 1 },
  { "name": "Bench Press (Dumbbell)", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 2 },
  { "name": "Incline Bench Press (Dumbbell)", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 3 },
  { "name": "Butterfly (Machine)", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 4 },
  { "name": "Dumbbell Flyes", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 5 },
  { "name": "Incline Dumbbell Flyes", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 6 },
  { "name": "Cable Crossovers", "category": "Chest", "defaultRestDuration": 90, "sortOrder": 7 },
  { "name": "Push-ups", "category": "Chest", "defaultRestDuration": 60, "sortOrder": 8 },
  
  { "name": "Deadlift", "category": "Back", "defaultRestDuration": 120, "sortOrder": 10 },
  { "name": "Pull-ups", "category": "Back", "defaultRestDuration": 90, "sortOrder": 11 },
  { "name": "Lat Pulldown", "category": "Back", "defaultRestDuration": 90, "sortOrder": 12 },
  { "name": "Behind-the-Neck Lat Pulldown", "category": "Back", "defaultRestDuration": 90, "sortOrder": 13 },
  { "name": "Bent Over Row (Barbell)", "category": "Back", "defaultRestDuration": 90, "sortOrder": 14 },
  { "name": "Seated Cable Row", "category": "Back", "defaultRestDuration": 90, "sortOrder": 15 },
  
  { "name": "Squat (Barbell)", "category": "Legs", "defaultRestDuration": 120, "sortOrder": 20 },
  { "name": "Leg Press", "category": "Legs", "defaultRestDuration": 120, "sortOrder": 21 },
  { "name": "Leg Curl (Machine)", "category": "Legs", "defaultRestDuration": 90, "sortOrder": 22 },
  { "name": "Leg Extension (Machine)", "category": "Legs", "defaultRestDuration": 90, "sortOrder": 23 },
  { "name": "Lunges", "category": "Legs", "defaultRestDuration": 90, "sortOrder": 24 },
  { "name": "Calf Raises", "category": "Legs", "defaultRestDuration": 60, "sortOrder": 25 },
  
  { "name": "Shoulder Press (Dumbbell)", "category": "Shoulders", "defaultRestDuration": 90, "sortOrder": 30 },
  { "name": "Military Press (Barbell)", "category": "Shoulders", "defaultRestDuration": 90, "sortOrder": 31 },
  { "name": "Lateral Raises (Dumbbell)", "category": "Shoulders", "defaultRestDuration": 60, "sortOrder": 32 },
  { "name": "Face Pulls (Cable)", "category": "Shoulders", "defaultRestDuration": 60, "sortOrder": 33 },
  
  { "name": "Bicep Curls (Dumbbell)", "category": "Arms", "defaultRestDuration": 60, "sortOrder": 40 },
  { "name": "Hammer Curls", "category": "Arms", "defaultRestDuration": 60, "sortOrder": 41 },
  { "name": "Triceps Pushdown (Cable)", "category": "Arms", "defaultRestDuration": 60, "sortOrder": 42 },
  { "name": "Dips", "category": "Arms", "defaultRestDuration": 90, "sortOrder": 43 },
  { "name": "French Press (EZ Bar)", "category": "Arms", "defaultRestDuration": 60, "sortOrder": 44 },
  
  { "name": "Crunches", "category": "Abs / Core", "defaultRestDuration": 60, "sortOrder": 50 },
  { "name": "Hanging Leg Raises", "category": "Abs / Core", "defaultRestDuration": 60, "sortOrder": 51 },
  { "name": "Plank", "category": "Abs / Core", "defaultRestDuration": 60, "sortOrder": 52 },
  { "name": "Cable Crunches", "category": "Abs / Core", "defaultRestDuration": 60, "sortOrder": 53 },
  
  { "name": "Treadmill", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 60 },
  { "name": "Rowing Machine", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 61 },
  { "name": "Stationary Bike", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 62 },
  { "name": "Stairmaster", "category": "Cardio", "defaultRestDuration": 0, "sortOrder": 63 },
  
  { "name": "Burpees", "category": "Uncategorized", "defaultRestDuration": 60, "sortOrder": 70 }
]
"""

guard let dataEn = jsonStringEn.data(using: .utf8) else { fatalError("Data error") }
do {
    let _ = try JSONDecoder().decode([SeedExercise].self, from: dataEn)
    print("SUCCESS JSON EN")
} catch {
    print("ERROR EN: \\(error)")
}
