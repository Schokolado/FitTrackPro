require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add StepEntry.swift
models_group = project.main_group.find_subpath(File.join('Core', 'Models'), true)
models_group.set_source_tree('<group>')
step_entry_ref = models_group.new_reference('StepEntry.swift')
target.add_file_references([step_entry_ref])

# Add Features/Steps
features_group = project.main_group.find_subpath('Features', true)
steps_group = features_group.find_subpath('Steps', true)
steps_group.set_source_tree('<group>')

step_tracker_ref = steps_group.new_reference('StepTrackerView.swift')
step_entry_form_ref = steps_group.new_reference('StepEntryFormView.swift')

target.add_file_references([step_tracker_ref, step_entry_form_ref])

project.save
puts "Added Step files to Xcode project."
