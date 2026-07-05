require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find Features group
features_group = project.main_group.children.find { |c| c.name == 'Features' || c.path == 'Features' }

['WaterTracker', 'SleepTracker', 'Recovery'].each do |sub_name|
  sub_group = features_group.children.find { |c| c.name == sub_name || c.path == sub_name }
  if sub_group
    sub_group.set_path(sub_name)
    sub_group.name = sub_name
  end
end

project.save
