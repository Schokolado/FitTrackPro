require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add the file to the project group so it's visible, but not to any build phase (Info.plist shouldn't be copied or compiled directly)
group = project.main_group.find_subpath('FitTrackPro/App', true)
file_ref = group.files.find { |f| f.path == 'Info.plist' }
unless file_ref
  file_ref = group.new_reference('Info.plist')
end

target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'App/Info.plist'
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_Generation')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIColorName')
    config.build_settings.delete('INFOPLIST_KEY_UILaunchScreen_UIImageName')
end

project.save
puts "Successfully added Info.plist and cleaned build settings."
