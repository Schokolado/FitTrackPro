require "xcodeproj"

project_path = "FitTrackPro.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

main_group = project.main_group

def find_or_create_nested_group(main_group, path_parts)
  path_parts.reduce(main_group) do |parent, name|
    parent[name] || parent.new_group(name, name)
  end
end

files_to_add = [
  [["Core", "Services"], "Core/Services/FoodAPIService.swift"],
  [["Features", "Nutrition"], "Features/Nutrition/NutritionDashboardView.swift"],
  [["Features", "Nutrition"], "Features/Nutrition/FoodEntryFormView.swift"],
  [["Features", "Nutrition"], "Features/Nutrition/BarcodeScannerView.swift"],
]

files_to_add.each do |group_path, file_path|
  full_path = File.join(File.dirname(File.expand_path(project_path)), file_path)
  
  group = find_or_create_nested_group(main_group, group_path)

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
puts "Done"
