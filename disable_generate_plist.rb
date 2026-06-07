require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    config.build_settings['INFOPLIST_FILE'] = 'App/Info.plist'
end

project.save
puts "Disabled GENERATE_INFOPLIST_FILE"
