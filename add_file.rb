require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add Features/Dashboard/DashboardDragDrop.swift
features_group = project.main_group.find_subpath(File.join('FitTrackPro', 'Features', 'Dashboard'), true)
file_ref = features_group.new_reference('DashboardDragDrop.swift')
target.source_build_phase.add_file_reference(file_ref)

project.save
puts "Added DashboardDragDrop.swift to Xcode project."
