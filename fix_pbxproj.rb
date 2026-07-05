require 'xcodeproj'
project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Remove any files that don't exist on disk
project.main_group.recursive_children.each do |node|
  if node.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    path = node.real_path.to_s
    if !File.exist?(path)
      puts "Removing missing file: #{path}"
      node.remove_from_project
    end
  end
end

project.save
