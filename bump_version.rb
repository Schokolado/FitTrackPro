require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
    config.build_settings['CURRENT_PROJECT_VERSION'] = '3'
end

project.save
puts "Bumped CURRENT_PROJECT_VERSION to 3"
