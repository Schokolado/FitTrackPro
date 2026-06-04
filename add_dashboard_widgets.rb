require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath('Features/Dashboard', true)
file_ref = group.new_reference('DashboardWidgets.swift')
target.add_file_references([file_ref])
project.save
