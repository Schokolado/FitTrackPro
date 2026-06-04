with open("Features/Training/Plans/TrainingPlansView.swift", "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if i >= 165 and i <= 175:
        if i == 165:
            new_lines.append(line) # 166: } (end ScrollView)
            new_lines.append("                }\n") # end VStack
            new_lines.append("            }\n") # end else
            new_lines.append("        }\n") # end Group
            new_lines.append("        .navigationDestination(isPresented: isNewPlanPresented) {\n")
            new_lines.append("            if let plan = plans.first(where: { $0.id.uuidString == newlyCreatedPlanId }) {\n")
            new_lines.append("                PlanDetailView(plan: plan)\n")
            new_lines.append("            }\n")
            new_lines.append("        }\n")
    else:
        new_lines.append(line)

with open("Features/Training/Plans/TrainingPlansView.swift", "w") as f:
    f.writelines(new_lines)
