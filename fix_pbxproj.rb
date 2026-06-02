require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('FitTrackPro/Core/Views', true)
file_path = 'Core/Views/ZoomableImageView.swift'
file_ref = group.new_file(file_path)
target.add_file_references([file_ref])

project.save
