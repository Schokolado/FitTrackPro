require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group_rec = project.main_group.find_subpath('Features/Recovery', true)
file1 = group_rec.new_file('RecoveryFactorDetailView.swift')

target.source_build_phase.add_file_reference(file1)

project.save
puts "Added RecoveryFactorDetailView.swift to target"
