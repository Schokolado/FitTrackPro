require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group
file_ref = group.new_file('VigrLaunchLogo_raw.png')
target.resources_build_phase.add_file_reference(file_ref)
project.save
