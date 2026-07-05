require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group_sleep = project.main_group.find_subpath('Features/SleepTracker', true)
file1 = group_sleep.new_file('SleepTrackerView.swift')
file2 = group_sleep.new_file('SleepEntryFormView.swift')

group_dashboard = project.main_group.find_subpath('Features/Dashboard', true)
file3 = group_dashboard.new_file('SleepTrackerCard.swift')

target.source_build_phase.add_file_reference(file1)
target.source_build_phase.add_file_reference(file2)
target.source_build_phase.add_file_reference(file3)

project.save
