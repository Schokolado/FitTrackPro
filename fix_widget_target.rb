require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_target = project.targets.find { |t| t.name == 'FitTrackProWidgetExtension' }
group = project.main_group.find_subpath('Core/Models', true)

file1 = group.children.find { |f| f.name == 'WaterEntry.swift' || f.path == 'WaterEntry.swift' }
file2 = group.children.find { |f| f.name == 'SleepEntry.swift' || f.path == 'SleepEntry.swift' }

widget_target.source_build_phase.add_file_reference(file1) if file1 && !widget_target.source_build_phase.files.any? { |bf| bf.file_ref == file1 }
widget_target.source_build_phase.add_file_reference(file2) if file2 && !widget_target.source_build_phase.files.any? { |bf| bf.file_ref == file2 }

project.save
