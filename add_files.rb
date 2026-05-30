require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

main_group = project.main_group

# Helper to find or create nested groups from main_group
def find_or_create_nested_group(main_group, path_parts)
  path_parts.reduce(main_group) do |parent, name|
    parent[name] || parent.new_group(name, name)
  end
end

# Files to add: [group path parts array, filesystem path relative to project root]
files_to_add = [
  # Red: SettingsView in proper location
  [['Features', 'Settings'],              'Features/Settings/SettingsView.swift'],
  # Yellow: New extension files
  [['Core', 'Extensions'],                'Core/Extensions/NotificationNames.swift'],
  [['Core', 'Extensions'],                'Core/Extensions/Logger+App.swift'],
  [['Core', 'Extensions'],                'Core/Extensions/TrainingPlan+Grouping.swift'],
]

files_to_add.each do |group_path, file_path|
  full_path = File.join(File.dirname(File.expand_path(project_path)), file_path)
  unless File.exist?(full_path)
    puts "SKIP (not found): #{file_path}"
    next
  end

  group = find_or_create_nested_group(main_group, group_path)

  # Skip if already referenced in this group
  base_name = File.basename(file_path)
  if group.files.any? { |f| f.path == base_name }
    puts "Already in project: #{file_path}"
    next
  end

  file_ref = group.new_file(base_name)
  target.add_file_references([file_ref])
  puts "Added: #{file_path}"
end

project.save
puts "Done – project saved."
