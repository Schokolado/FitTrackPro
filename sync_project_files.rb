require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# All Swift files that SHOULD be in the build target but aren't yet.
# Format: [group path components, file path relative to project root]
missing_files = [
  # App
  [['App'],                                               'App/AppRouter.swift'],
  [['App'],                                               'App/FitTrackProApp.swift'],

  # Core – Extensions
  [['Core', 'Extensions'],                                'Core/Extensions/AppStorageKeys.swift'],
  [['Core', 'Extensions'],                                'Core/Extensions/Color+Theme.swift'],
  [['Core', 'Extensions'],                                'Core/Extensions/Logger+App.swift'],
  [['Core', 'Extensions'],                                'Core/Extensions/NotificationNames.swift'],
  [['Core', 'Extensions'],                                'Core/Extensions/TrainingPlan+Grouping.swift'],
  [['Core', 'Extensions'],                                'Core/Extensions/View+Modifiers.swift'],

  # Core – Models
  [['Core', 'Models'],                                    'Core/Models/DailyLog.swift'],
  [['Core', 'Models'],                                    'Core/Models/Exercise.swift'],
  [['Core', 'Models'],                                    'Core/Models/FoodEntry.swift'],
  [['Core', 'Models'],                                    'Core/Models/PlanExercise.swift'],
  [['Core', 'Models'],                                    'Core/Models/TrainingPlan.swift'],
  [['Core', 'Models'],                                    'Core/Models/WeightEntry.swift'],
  [['Core', 'Models'],                                    'Core/Models/WorkoutSession.swift'],
  [['Core', 'Models'],                                    'Core/Models/WorkoutSet.swift'],

  # Core – Services
  [['Core', 'Services'],                                  'Core/Services/ExerciseService.swift'],
  [['Core', 'Services'],                                  'Core/Services/NotificationService.swift'],
  [['Core', 'Services'],                                  'Core/Services/SeedDataService.swift'],

  # Features – Training – ExerciseLibrary
  [['Features', 'Training', 'ExerciseLibrary'],           'Features/Training/ExerciseLibrary/ExerciseDetailView.swift'],
  [['Features', 'Training', 'ExerciseLibrary'],           'Features/Training/ExerciseLibrary/ExerciseFormView.swift'],
  [['Features', 'Training', 'ExerciseLibrary'],           'Features/Training/ExerciseLibrary/ExerciseLibraryView.swift'],
  [['Features', 'Training', 'ExerciseLibrary'],           'Features/Training/ExerciseLibrary/ExerciseLibraryViewModel.swift'],

  # Features – Training – Plans
  [['Features', 'Training', 'Plans'],                     'Features/Training/Plans/ExerciseSelectionView.swift'],
  [['Features', 'Training', 'Plans'],                     'Features/Training/Plans/PlanDetailView.swift'],
  [['Features', 'Training', 'Plans'],                     'Features/Training/Plans/PlanExerciseRowView.swift'],
  [['Features', 'Training', 'Plans'],                     'Features/Training/Plans/TrainingPlansView.swift'],

  # Features – Training – Workout
  [['Features', 'Training', 'Workout'],                   'Features/Training/Workout/ExerciseHistoryView.swift'],
  [['Features', 'Training', 'Workout'],                   'Features/Training/Workout/WorkoutSessionView.swift'],
  [['Features', 'Training', 'Workout'],                   'Features/Training/Workout/WorkoutSessionViewModel.swift'],
  [['Features', 'Training', 'Workout'],                   'Features/Training/Workout/WorkoutSetRowView.swift'],
  [['Features', 'Training', 'Workout'],                   'Features/Training/Workout/WorkoutSummaryView.swift'],

  # Features – Settings
  [['Features', 'Settings'],                              'Features/Settings/SettingsView.swift'],
]

# Build a set of already-registered file paths to avoid double-adding
already_registered = Set.new(
  target.source_build_phase.files.map { |f| f.file_ref&.real_path&.to_s }.compact
)

added = 0
missing_files.each do |group_path, rel_path|
  full_path = File.expand_path(rel_path, File.dirname(project_path))
  next unless File.exist?(full_path)
  next if already_registered.include?(full_path)

  # Navigate / create group hierarchy
  group = project.main_group
  group_path.each do |component|
    group = group[component] || group.new_group(component, component)
  end

  base = File.basename(rel_path)
  # Only add file reference if not already in group
  file_ref = group.files.find { |f| f.path == base }
  unless file_ref
    file_ref = group.new_file(base)
  end

  # Only add to build phase if not already there
  unless target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
    target.add_file_references([file_ref])
    puts "Added: #{rel_path}"
    added += 1
  else
    puts "Already in target: #{rel_path}"
  end
end

project.save
puts "\nDone – added #{added} files to target."
