require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main app target
app_target = project.targets.find { |t| t.product_type == 'com.apple.product-type.application' }

# Recreate the scheme
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.set_launch_target(app_target)

# Ensure the shared data dir exists
shared_data_dir = File.join(project_path, 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(shared_data_dir)

# Save the scheme
scheme_path = File.join(shared_data_dir, "#{app_target.name}.xcscheme")
scheme.save_as(project_path, app_target.name, true)

puts "Scheme created at #{scheme_path}"
