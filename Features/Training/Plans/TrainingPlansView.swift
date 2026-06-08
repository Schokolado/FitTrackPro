import SwiftUI
import SwiftData

enum PlanGroupFilter: Hashable {
    case all
    case unassigned
    case group(UUID)
}

struct DisplayGroup: Identifiable, Equatable {
    let id: String
    let name: String
    let isUnassigned: Bool
    var sortOrder: Int
    let planCount: Int
    let realGroup: PlanGroup?
}

struct TrainingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlan.sortOrder) private var plans: [TrainingPlan]
    @Query(sort: \PlanGroup.sortOrder) private var groups: [PlanGroup]
    @AppStorage("unassignedGroupSortOrder") private var unassignedSortOrder: Int = -1
    
    @Binding var triggerAddAlert: Bool
    @State private var showingRenameAlert = false
    @State private var newPlanName = ""
    @State private var planToRename: TrainingPlan? = nil
    @State private var selectedFilter: PlanGroupFilter = .all
    @State private var showingFilterSheet = false
    
    @State private var showingCreateGroupForPlanAlert = false
    @State private var newGroupNameForPlan = ""
    @State private var planToGroup: TrainingPlan? = nil
    
    @State private var newlyCreatedPlanId: String = ""
    private var isNewPlanPresented: Binding<Bool> {
        Binding(
            get: { !newlyCreatedPlanId.isEmpty },
            set: { if !$0 { newlyCreatedPlanId = "" } }
        )
    }
    
    private var filteredPlans: [TrainingPlan] {
        switch selectedFilter {
        case .all:
            return plans
        case .unassigned:
            return plans.filter { $0.group == nil }
        case .group(let id):
            return plans.filter { $0.group?.id == id }
        }
    }
    
    var displayGroups: [DisplayGroup] {
        let finalUnassignedOrder = unassignedSortOrder == -1 ? Int.max : unassignedSortOrder
        var items = groups.map { DisplayGroup(id: $0.id.uuidString, name: $0.name, isUnassigned: false, sortOrder: $0.sortOrder, planCount: $0.plans?.count ?? 0, realGroup: $0) }
        let unassignedCount = plans.filter { $0.group == nil }.count
        items.append(DisplayGroup(id: "unassigned", name: "Nicht zugeordnet", isUnassigned: true, sortOrder: finalUnassignedOrder, planCount: unassignedCount, realGroup: nil))
        items.sort { $0.sortOrder < $1.sortOrder }
        return items
    }
    
    var body: some View {
        Group {
            if plans.isEmpty {
                ContentUnavailableView(
                    "Keine Trainingspläne",
                    systemImage: "list.clipboard",
                    description: Text("Füge einen neuen Trainingsplan über das '+' unten rechts hinzu.")
                )
            } else {
                VStack(spacing: 0) {
                    // Chips Header
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            HStack(spacing: 12) {
                                Button {
                                    showingFilterSheet = true
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.backgroundSecondary)
                                        .clipShape(Capsule())
                                }
                                
                                PlanGroupFilterChip(title: "Alle", isSelected: selectedFilter == .all) {
                                    selectedFilter = .all
                                }
                                .id("filter_all")
                                
                                ForEach(displayGroups) { item in
                                    if item.isUnassigned {
                                        PlanGroupFilterChip(title: item.name, isSelected: selectedFilter == .unassigned) {
                                            selectedFilter = .unassigned
                                        }
                                        .id("filter_unassigned")
                                    } else if let group = item.realGroup {
                                        PlanGroupFilterChip(title: item.name, isSelected: selectedFilter == .group(group.id)) {
                                            selectedFilter = .group(group.id)
                                        }
                                        .id("filter_\(group.id.uuidString)")
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .onChange(of: selectedFilter) { _, newValue in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        switch newValue {
                                        case .all:
                                            proxy.scrollTo("filter_all", anchor: .center)
                                        case .unassigned:
                                            proxy.scrollTo("filter_unassigned", anchor: .center)
                                        case .group(let id):
                                            proxy.scrollTo("filter_\(id.uuidString)", anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .background(Color.backgroundPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if filteredPlans.isEmpty {
                                Text("Keine Pläne in dieser Gruppe")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 40)
                            } else {
                                ForEach(Array(filteredPlans.enumerated()), id: \.element.id) { index, plan in
                                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                                        PlanCardView(
                                            plan: plan, 
                                            index: index, 
                                            groups: groups,
                                            onRename: {
                                                planToRename = plan
                                                newPlanName = plan.name
                                                showingRenameAlert = true
                                            }, 
                                            onDuplicate: {
                                                duplicate(plan: plan)
                                            }, 
                                            onDelete: {
                                                modelContext.delete(plan)
                                            },
                                            onCreateGroup: {
                                                planToGroup = plan
                                                newGroupNameForPlan = ""
                                                showingCreateGroupForPlanAlert = true
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationDestination(isPresented: isNewPlanPresented) {
            if let plan = plans.first(where: { $0.id.uuidString == newlyCreatedPlanId }) {
                PlanDetailView(plan: plan)
            }
        }
        .alert("Neuer Trainingsplan", isPresented: $triggerAddAlert) {
            TextField("Name", text: $newPlanName)
            Button("Abbrechen", role: .cancel) { }
            Button("Erstellen") {
                createPlan()
            }
            .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .alert("Plan umbenennen", isPresented: $showingRenameAlert) {
            TextField("Name", text: $newPlanName)
            Button("Abbrechen", role: .cancel) { }
            Button("Speichern") {
                if let plan = planToRename {
                    plan.name = newPlanName
                }
            }
            .disabled(newPlanName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .sheet(isPresented: $showingFilterSheet) {
            PlanGroupFilterSheetView(selectedFilter: $selectedFilter, groups: displayGroups)
        }
        .alert("Neue Gruppe", isPresented: $showingCreateGroupForPlanAlert) {
            TextField("Gruppenname", text: $newGroupNameForPlan)
            Button("Abbrechen", role: .cancel) { }
            Button("Erstellen") {
                if let plan = planToGroup {
                    let newGroup = PlanGroup(name: newGroupNameForPlan, sortOrder: groups.count)
                    modelContext.insert(newGroup)
                    plan.group = newGroup
                }
            }
            .disabled(newGroupNameForPlan.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
    
    private func createPlan() {
        // If a specific group is selected, pre-assign it
        var preselectedGroup: PlanGroup? = nil
        if case .group(let id) = selectedFilter {
            preselectedGroup = groups.first { $0.id == id }
        }
        let plan = TrainingPlan(name: newPlanName, sortOrder: plans.count, group: preselectedGroup)
        modelContext.insert(plan)
        newPlanName = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            newlyCreatedPlanId = plan.id.uuidString
        }
    }
    
    private func duplicate(plan: TrainingPlan) {
        let newPlan = TrainingPlan(name: "\(plan.name) (Kopie)", sortOrder: plans.count, group: plan.group)
        modelContext.insert(newPlan)
        // Copy exercises
        if let exercises = plan.planExercises {
            for (index, planEx) in exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
                let newEx = PlanExercise(
                    sortOrder: index,
                    supersetGroup: planEx.supersetGroup,
                    targetSets: planEx.targetSets,
                    targetReps: planEx.targetReps,
                    targetWeight: planEx.targetWeight,
                    restDuration: planEx.restDuration,
                    plan: newPlan,
                    exercise: planEx.exercise
                )
                modelContext.insert(newEx)
            }
        }
    }
}

struct PlanGroupFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.brand : Color.backgroundSecondary)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.brand.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
    }
}

struct PlanCardView: View {
    let plan: TrainingPlan
    let index: Int
    let groups: [PlanGroup]
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onCreateGroup: () -> Void
    
    @State private var showingShareSheet = false
    @State private var generatedPDFUrl: URL? = nil
    @State private var isGeneratingPDF = false
    @State private var showingDeleteAlert = false
    
    private var lastCompletedSession: WorkoutSession? {
        plan.sessions?
            .filter { $0.endTime != nil }
            .sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }
            .first
    }
    
    private func exportEmptyPlan() {
        isGeneratingPDF = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportEmptyPlan(plan) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }

    private func exportHistoricalPlan() {
        isGeneratingPDF = true
        let sessions = plan.sessions?.sorted(by: { ($0.startTime ?? Date.distantPast) > ($1.startTime ?? Date.distantPast) }) ?? []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = PDFExportService.shared.exportHistoricalPlan(plan: plan, sessions: sessions) {
                self.generatedPDFUrl = url
                self.showingShareSheet = true
            }
            self.isGeneratingPDF = false
        }
    }
    
    private func lastCompletedText(for date: Date?) -> String {
        guard let date = date else { return "noch nie absolviert" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "heute absolviert"
        }
        
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        
        if let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day, days > 0 {
            if days == 1 {
                return "zuletzt vor 1 Tag"
            } else {
                return "zuletzt vor \(days) Tagen"
            }
        }
        
        return "heute absolviert"
    }
    
    private var gradient: LinearGradient {
        let colors: [[Color]] = [
            [Color.brand, Color.brandSecondary],
            [Color.orange, Color.red],
            [Color.purple, Color.indigo],
            [Color.cyan, Color.mint],
            [Color.pink, Color.orange]
        ]
        let pair = colors[index % colors.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(plan.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(lastCompletedText(for: lastCompletedSession?.endTime))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer(minLength: 20)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                        Text("\(plan.planExercises?.count ?? 0) Übungen")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    
                    if let group = plan.group {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                            Text(group.name)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    gradient
                    Color.white.opacity(0.15)
                }
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .overlay {
                if isGeneratingPDF {
                    ZStack {
                        Color.black.opacity(0.4)
                            .cornerRadius(20)
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("PDF erstellen...")
                                .font(.footnote)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            
            // Menu
            Menu {
                Menu {
                    Button {
                        exportEmptyPlan()
                    } label: {
                        Label("Leerer Plan (Vorlage)", systemImage: "doc.text")
                    }
                    Button {
                        exportHistoricalPlan()
                    } label: {
                        Label("Historie inkl. Daten", systemImage: "chart.bar.doc.horizontal")
                    }
                } label: {
                    Label("Als PDF exportieren", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Menu {
                    Button {
                        plan.group = nil
                    } label: {
                        HStack {
                            Text("Nicht zugeordnet")
                            if plan.group == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(groups) { group in
                        Button {
                            plan.group = group
                        } label: {
                            HStack {
                                Text(group.name)
                                if plan.group?.id == group.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        onCreateGroup()
                    } label: {
                        Label("Neue Gruppe erstellen", systemImage: "plus")
                    }
                } label: {
                    Label("Gruppe zuweisen", systemImage: "folder")
                }
                
                Divider()
                
                Button {
                    onRename()
                } label: {
                    Label("Umbenennen", systemImage: "pencil")
                }
                
                Button {
                    onDuplicate()
                } label: {
                    Label("Duplizieren", systemImage: "doc.on.doc")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(16)
                    .contentShape(Rectangle())
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = generatedPDFUrl {
                ShareSheet(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Plan löschen", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Bist du sicher, dass du den Trainingsplan '\(plan.name)' unwiderruflich löschen möchtest?")
        }
    }
}

struct PlanGroupManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \PlanGroup.sortOrder) private var groups: [PlanGroup]
    @Query private var plans: [TrainingPlan]
    @AppStorage("unassignedGroupSortOrder") private var unassignedSortOrder: Int = -1
    
    @State private var showingAddAlert = false
    @State private var newGroupName = ""
    
    @State private var showingEditAlert = false
    @State private var groupToEdit: PlanGroup?
    @State private var editGroupName = ""
    
    var displayGroups: [DisplayGroup] {
        let finalUnassignedOrder = unassignedSortOrder == -1 ? Int.max : unassignedSortOrder
        var items = groups.map { DisplayGroup(id: $0.id.uuidString, name: $0.name, isUnassigned: false, sortOrder: $0.sortOrder, planCount: $0.plans?.count ?? 0, realGroup: $0) }
        let unassignedCount = plans.filter { $0.group == nil }.count
        items.append(DisplayGroup(id: "unassigned", name: "Nicht zugeordnet", isUnassigned: true, sortOrder: finalUnassignedOrder, planCount: unassignedCount, realGroup: nil))
        items.sort { $0.sortOrder < $1.sortOrder }
        return items
    }
    
    var body: some View {
        List {
            ForEach(displayGroups) { item in
                HStack {
                    Text(item.name)
                        .foregroundColor(item.isUnassigned ? .secondary : .primary)
                    Spacer()
                    Text("\(item.planCount) Pläne")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !item.isUnassigned {
                        groupToEdit = item.realGroup
                        editGroupName = item.name
                        showingEditAlert = true
                    }
                }
                .deleteDisabled(item.isUnassigned)
            }
            .onDelete(perform: deleteGroup)
            .onMove(perform: moveGroup)
        }
            .navigationTitle("Gruppen verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAlert = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .alert("Neue Gruppe", isPresented: $showingAddAlert) {
                TextField("Gruppenname", text: $newGroupName)
                Button("Abbrechen", role: .cancel) { }
                Button("Erstellen") {
                    let newGroup = PlanGroup(name: newGroupName, sortOrder: groups.count)
                    modelContext.insert(newGroup)
                    newGroupName = ""
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .alert("Gruppe umbenennen", isPresented: $showingEditAlert) {
                TextField("Gruppenname", text: $editGroupName)
                Button("Abbrechen", role: .cancel) { }
                Button("Speichern") {
                    if let group = groupToEdit {
                        group.name = editGroupName
                    }
                }
                .disabled(editGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
    }
    
    private func deleteGroup(at offsets: IndexSet) {
        for index in offsets {
            let item = displayGroups[index]
            if !item.isUnassigned, let group = item.realGroup {
                modelContext.delete(group)
            }
        }
    }
    
    private func moveGroup(from source: IndexSet, to destination: Int) {
        var revisedItems = displayGroups
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            if item.isUnassigned {
                // If it's moved to the very end, reset to -1 so it stays at the end when new groups are added
                unassignedSortOrder = (index == revisedItems.count - 1) ? -1 : index
            } else if let group = item.realGroup {
                group.sortOrder = index
            }
        }
    }
}
import SwiftUI

struct TrainingMainView: View {
    @AppStorage("trainingSelectedTab") private var selectedTab = 0
    @State private var isFabExpanded = false
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(WorkoutManager.self) private var workoutManager
    
    @State private var triggerAddPlan = false
    @State private var triggerAddExercise = false
    @State private var navId = UUID()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $selectedTab) {
                    Text("Pläne").tag(0)
                    Text("Übungen").tag(1)
                    Text("Historie").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.backgroundPrimary)
                
                if selectedTab == 0 {
                    TrainingPlansView(triggerAddAlert: $triggerAddPlan)
                } else if selectedTab == 1 {
                    ExerciseLibraryView(triggerAddExercise: $triggerAddExercise)
                } else {
                    WorkoutHistoryView()
                }
                
                Spacer(minLength: 0)
            }
            .background(Color.backgroundPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: StatisticsView()) {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.primary)
                    }
                }
            }
            .overlay {
                if isFabExpanded {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                        }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 16) {
                    if isFabExpanded {
                        // Workout starten Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                            selectedTab = 0
                        }) {
                            HStack {
                                Text("Workout starten")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(uiColor: .systemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                        
                        // Neuer Plan Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                            selectedTab = 0
                            // Delay slightly to allow tab switch
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                triggerAddPlan = true
                            }
                        }) {
                            HStack {
                                Text("Neuer Plan")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(uiColor: .systemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color.brandSecondary)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                        
                        // Neue Übung Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFabExpanded = false
                            }
                            selectedTab = 1
                            // Delay slightly to allow tab switch
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                triggerAddExercise = true
                            }
                        }) {
                            HStack {
                                Text("Neue Übung")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(uiColor: .systemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "dumbbell.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color.brand)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    
                    // Main FAB
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isFabExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.brand)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                            .rotationEffect(.degrees(isFabExpanded ? 45 : 0))
                    }
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
        }
        .id(navId)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TabReselected"))) { notification in
            if let tab = notification.object as? Int, tab == 1 {
                UserDefaults.standard.set("", forKey: "openHistorySessionId")
                navId = UUID()
            }
        }
    }
}

struct PlanGroupFilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFilter: PlanGroupFilter
    let groups: [DisplayGroup]
    
    @State private var searchText = ""
    
    var filteredGroups: [DisplayGroup] {
        if searchText.isEmpty {
            return groups
        } else {
            return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedFilter = .all
                        dismiss()
                    } label: {
                        HStack {
                            Text("Alle")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedFilter == .all {
                                Image(systemName: "checkmark").foregroundColor(.brand)
                            }
                        }
                    }
                }
                
                Section(header: Text("Gruppen")) {
                    if filteredGroups.isEmpty {
                        Text("Keine Gruppen gefunden")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredGroups) { group in
                            Button {
                                if group.isUnassigned {
                                    selectedFilter = .unassigned
                                } else if let g = group.realGroup {
                                    selectedFilter = .group(g.id)
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    Text(group.name)
                                        .foregroundColor(group.isUnassigned ? .secondary : .primary)
                                    Spacer()
                                    
                                    let isSelected: Bool = {
                                        if group.isUnassigned {
                                            return selectedFilter == .unassigned
                                        } else if let g = group.realGroup {
                                            return selectedFilter == .group(g.id)
                                        }
                                        return false
                                    }()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark").foregroundColor(.brand)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Gruppe suchen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: PlanGroupManagerView()) {
                        Text("Verwalten")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
