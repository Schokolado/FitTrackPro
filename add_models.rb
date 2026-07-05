require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath('Core/Models', true)
file1 = group.new_file('WaterEntry.swift')
file2 = group.new_file('SleepEntry.swift')
target.source_build_phase.add_file_reference(file1)
target.source_build_phase.add_file_reference(file2)
project.save
