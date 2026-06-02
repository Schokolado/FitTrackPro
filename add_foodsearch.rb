require 'xcodeproj'
project = Xcodeproj::Project.open('FitTrackPro.xcodeproj')
target = project.targets.first
group = project.main_group.find_subpath('FitTrackPro/Features/Nutrition', true)
file_ref = group.new_file('Features/Nutrition/FoodSearchView.swift')
target.add_file_references([file_ref])
project.save
