require 'xcodeproj'

project_path = 'FitTrackPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

main_group = project.main_group

def find_or_create_nested_group(main_group, path_parts)
  path_parts.reduce(main_group) do |parent, name|
    parent[name] || parent.new_group(name, name)
  end
end

files_to_add = [
  [['Core', 'UI'], 'Core/UI/ShareSheet.swift'],
  [['Core', 'Services'], 'Core/Services/PDFExportService.swift'],
  [['Features', 'Training', 'Plans', 'PDF'], 'Features/Training/Plans/PDF/PDFEmptyPlanTemplate.swift'],
  [['Features', 'Training', 'Plans', 'PDF'], 'Features/Training/Plans/PDF/PDFHistoricalPlanTemplate.swift'],
]

files_to_add.each do |group_path, file_path|
  full_path = File.join(File.dirname(File.expand_path(project_path)), file_path)
  unless File.exist?(full_path)
    puts "SKIP (not found): #{file_path}"
    next
  end

  group = find_or_create_nested_group(main_group, group_path)
  base_name = File.basename(file_path)

  # Remove existing reference if any to avoid dangling duplicates
  existing = group.files.find { |f| f.path == base_name }
  if existing
    existing.remove_from_project
  end

  # Remove from target build phase to be safe
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path == base_name
      build_file.remove_from_project
    end
  end

  file_ref = group.new_file(base_name)
  target.add_file_references([file_ref])
  puts "Added: #{file_path}"
end

project.save
puts "Done."
