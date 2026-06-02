require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

def ensure_group(project, path_string)
  components = path_string.split('/')
  current_group = project.main_group['FitTrackPro']
  components.each do |comp|
    next if comp.empty?
    existing = current_group.children.find { |c| c.display_name == comp || c.path == comp }
    current_group = existing || current_group.new_group(comp, comp)
  end
  current_group
end

files_to_add = [
  'Features/Dashboard/DashboardView.swift',
  'Features/WeightTracker/WeightTrackerView.swift',
  'Features/WeightTracker/WeightEntryFormView.swift'
]

files_to_add.each do |file_path|
  dir_path = File.dirname(file_path)
  file_name = File.basename(file_path)
  
  group = ensure_group(project, dir_path)
  
  unless group.files.find { |f| f.path == file_name }
    file_ref = group.new_file(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_path}"
  end
end

project.save
puts "Project saved"
