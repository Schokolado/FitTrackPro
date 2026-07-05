require 'xcodeproj'
project = Xcodeproj::Project.open('FitTrackPro.xcodeproj')
target = project.targets.first

def add_file(project, target, file_path)
  group_path = File.dirname(file_path)
  group_names = group_path.split('/')
  
  current_group = project.main_group
  group_names.each do |name|
    next if name == '.'
    found_group = current_group.children.find { |c| c.class == Xcodeproj::Project::Object::PBXGroup && c.name == name }
    if found_group.nil?
      found_group = current_group.children.find { |c| c.class == Xcodeproj::Project::Object::PBXGroup && c.path == name }
    end
    if found_group.nil?
      found_group = current_group.new_group(name)
    end
    current_group = found_group
  end

  file_name = File.basename(file_path)
  unless current_group.files.any? { |f| f.path == file_name || f.name == file_name }
    file_ref = current_group.new_file(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_path}"
  else
    puts "Already exists: #{file_path}"
  end
end

add_file(project, target, 'Core/Models/SleepDaySummary.swift')
add_file(project, target, 'Features/SleepTracker/SleepDetailView.swift')

project.save
puts "Project saved"
