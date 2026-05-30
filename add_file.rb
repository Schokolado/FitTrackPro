require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
group = project.main_group['FitTrackPro']

# Create Settings group if it doesn't exist
settings_group = group['Features'] ? group['Features']['Settings'] : nil
if settings_group.nil?
  features_group = group['Features'] || group.new_group('Features', 'Features')
  settings_group = features_group.new_group('Settings', 'Settings')
end

file_ref = settings_group.new_file('SettingsView.swift')
target.add_file_references([file_ref])

project.save
