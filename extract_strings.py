import os
import re

swift_files = []
for root, dirs, files in os.walk('.'):
    for file in files:
        if file.endswith('.swift'):
            swift_files.append(os.path.join(root, file))

strings = set()
# Regex to match Text("..."), Button("..."), Label("..."), .navigationTitle("...")
patterns = [
    re.compile(r'Text\(\"([^\"]+)\"\)'),
    re.compile(r'Button\(\"([^\"]+)\"'),
    re.compile(r'Label\(\"([^\"]+)\"'),
    re.compile(r'\.navigationTitle\(\"([^\"]+)\"\)'),
    re.compile(r'String\(localized:\s*\"([^\"]+)\"\)')
]

for file_path in swift_files:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        for pattern in patterns:
            matches = pattern.findall(content)
            for match in matches:
                # exclude symbols and empty
                if len(match) > 0 and not match.startswith("systemImage:") and not match.startswith("Vigr"):
                    strings.add(match)

strings_list = sorted(list(strings))

with open('extracted_strings.txt', 'w', encoding='utf-8') as f:
    for s in strings_list:
        f.write(f"{s}\n")

print(f"Extracted {len(strings_list)} strings.")
