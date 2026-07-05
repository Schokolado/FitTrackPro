require 'xcodeproj'

project_path = '/Users/p016324/.gemini/antigravity/scratch/FitTrackPro/FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Helper to find or create group
def find_or_create_group(project, path_string)
  components = path_string.split('/')
  current_group = project.main_group
  components.each do |component|
    next_group = current_group.groups.find { |g| g.name == component || g.path == component }
    if next_group.nil?
      next_group = current_group.new_group(component, component)
    end
    current_group = next_group
  end
  current_group
end

# Core/Models
models_group = find_or_create_group(project, 'Core/Models')
config_file = models_group.new_file('DashboardLayoutConfig.swift')
target.add_file_references([config_file])

# Features/Dashboard
dashboard_group = find_or_create_group(project, 'Features/Dashboard')
small_file = dashboard_group.new_file('DashboardWidgetsSmall.swift')
large_file = dashboard_group.new_file('DashboardWidgetsLarge.swift')
target.add_file_references([small_file, large_file])

project.save
puts "Added files to Xcode project"
