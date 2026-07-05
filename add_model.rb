require 'xcodeproj'
project = Xcodeproj::Project.open('FitTrackPro.xcodeproj')
target = project.targets.first

group = project.main_group.children.find { |c| c.name == 'Core' }
if group.nil?
  group = project.main_group.new_group('Core')
end
models_group = group.children.find { |c| c.name == 'Models' }
if models_group.nil?
  models_group = group.new_group('Models')
end

file_path = 'Core/Models/SleepDaySummary.swift'
unless models_group.files.any? { |f| f.path == file_path }
  file_ref = models_group.new_file(file_path)
  target.add_file_references([file_ref])
  project.save
  puts "Added SleepDaySummary.swift"
else
  puts "Already exists"
end
