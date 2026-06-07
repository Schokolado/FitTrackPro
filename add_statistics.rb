require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.children.find { |g| g.display_name == 'Features' || g.path == 'Features' }
if group.nil?
    group = project.main_group.new_group('Features', 'Features')
end

stat_group = group.children.find { |g| g.display_name == 'Statistics' || g.path == 'Statistics' }
if stat_group.nil?
    stat_group = group.new_group('Statistics', 'Statistics')
end

files = [
  'Features/Statistics/StatisticsViewModel.swift',
  'Features/Statistics/ExerciseProgressChart.swift',
  'Features/Statistics/PlanProgressView.swift',
  'Features/Statistics/StatisticsView.swift'
]

files.each do |file_path|
  base = File.basename(file_path)
  # Only add file reference if not already in group
  file_ref = stat_group.files.find { |f| f.path == base }
  unless file_ref
    file_ref = stat_group.new_file(base)
  end

  # Only add to build phase if not already there
  unless target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
    target.add_file_references([file_ref])
    puts "Added: #{file_path}"
  else
    puts "Already in target: #{file_path}"
  end
end

project.save
