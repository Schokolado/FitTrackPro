require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group_rec = project.main_group.find_subpath('Features/Recovery', true)
file1 = group_rec.new_file('RecoveryCalculator.swift')
file2 = group_rec.new_file('RecoveryView.swift')

group_dashboard = project.main_group.find_subpath('Features/Dashboard', true)
file3 = group_dashboard.new_file('RecoveryCard.swift')

target.source_build_phase.add_file_reference(file1)
target.source_build_phase.add_file_reference(file2)
target.source_build_phase.add_file_reference(file3)

project.save
