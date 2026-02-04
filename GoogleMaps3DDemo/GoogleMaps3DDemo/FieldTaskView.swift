// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

// MARK: - Field & Task Management View

struct FieldTaskView: View {
    @ObservedObject var manager = FieldTaskManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showNewFarmSheet = false
    @State private var showNewFieldSheet = false
    @State private var showNewTaskSheet = false

    private let showsDoneButton: Bool

    init(showsDoneButton: Bool = false) {
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    FieldBeeSectionHeader("Farm", subtitle: "Set the primary operation.")
                    if let farm = manager.selectedFarm {
                        HStack(spacing: 12) {
                            Image(systemName: "house.fill")
                                .foregroundColor(FieldBeeColor.soil)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(farm.name)
                                    .font(.headline)
                                Text("\(manager.partfields.count) fields")
                                    .font(.caption)
                                    .foregroundColor(FieldBeeColor.slate)
                            }
                            Spacer()
                            FieldBeePill(text: "Active", color: FieldBeeColor.leaf)
                        }
                    } else {
                        Button(action: { showNewFarmSheet = true }) {
                            Label("Create Farm", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FieldBeeColor.leaf)
                    }
                }
                .listRowBackground(FieldBeeColor.panel)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        FieldBeeSectionHeader("Fields", subtitle: "Select a field to manage tasks.")
                        Spacer()
                        Button(action: { showNewFieldSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .tint(FieldBeeColor.leaf)
                        .disabled(manager.selectedFarm == nil)
                    }

                    if manager.partfields.isEmpty {
                        Text("No fields yet")
                            .foregroundColor(FieldBeeColor.slate)
                            .italic()
                    } else {
                        ForEach(manager.partfields) { field in
                            FieldRow(field: field, isSelected: manager.selectedPartfield?.id == field.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    manager.selectPartfield(field)
                                }
                        }
                        .onDelete(perform: deleteFields)
                    }
                }
                .listRowBackground(FieldBeeColor.panel)
            }

            if let selectedField = manager.selectedPartfield {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            FieldBeeSectionHeader("Tasks", subtitle: "Planned work for \(selectedField.name).")
                            Spacer()
                            Button(action: { showNewTaskSheet = true }) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .tint(FieldBeeColor.leaf)
                        }

                        if manager.tasks.isEmpty {
                            Text("No tasks yet")
                                .foregroundColor(FieldBeeColor.slate)
                                .italic()
                        } else {
                            ForEach(manager.tasks) { task in
                                TaskRow(task: task, isActive: manager.activeTask?.id == task.id)
                                    .swipeActions(edge: .leading) {
                                        if task.status == .pending || task.status == .paused {
                                            Button {
                                                manager.startTask(task)
                                            } label: {
                                                Label("Start", systemImage: "play.fill")
                                            }
                                            .tint(FieldBeeColor.leaf)
                                        } else if task.status == .inProgress {
                                            Button {
                                                manager.pauseTask(task)
                                            } label: {
                                                Label("Pause", systemImage: "pause.fill")
                                            }
                                            .tint(FieldBeeColor.sun)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        if task.status != .completed && task.status != .cancelled {
                                            Button {
                                                manager.completeTask(task)
                                            } label: {
                                                Label("Complete", systemImage: "checkmark")
                                            }
                                            .tint(FieldBeeColor.soil)
                                        }
                                    }
                            }
                            .onDelete(perform: deleteTasks)
                        }
                    }
                    .listRowBackground(FieldBeeColor.panel)
                }
            }

            if let activeTask = manager.activeTask {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        FieldBeeSectionHeader("Active Task", subtitle: "Current in-field execution.")
                        HStack(spacing: 12) {
                            Image(systemName: activeTask.taskType.systemImage)
                                .foregroundColor(FieldBeeColor.leaf)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activeTask.name)
                                    .font(.headline)
                                Text("Status: \(activeTask.status.displayName)")
                                    .font(.caption)
                                    .foregroundColor(FieldBeeColor.slate)
                            }
                            Spacer()
                            if let coverage = getCoverageForActiveTask() {
                                FieldBeePill(text: "\(coverage) cells", color: FieldBeeColor.soil)
                            }
                        }
                    }
                    .listRowBackground(FieldBeeColor.panel)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(FieldBeeColor.mist)
        .navigationTitle("Fields & Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showNewFarmSheet) {
            NewFarmSheet(manager: manager)
        }
        .sheet(isPresented: $showNewFieldSheet) {
            NewFieldSheet(manager: manager)
        }
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(manager: manager)
        }
    }

    private func deleteFields(at offsets: IndexSet) {
        for index in offsets {
            manager.deletePartfield(manager.partfields[index])
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            manager.deleteTask(manager.tasks[index])
        }
    }

    private func getCoverageForActiveTask() -> Int? {
        guard let taskId = manager.activeTask?.id else { return nil }
        return manager.getCoverageCount(taskId: taskId)
    }
}

// MARK: - Field Row

struct FieldRow: View {
    let field: ISOPartfield
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "square.dashed")
                .foregroundColor(isSelected ? FieldBeeColor.leaf : FieldBeeColor.slate)

            VStack(alignment: .leading, spacing: 2) {
                Text(field.name)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? FieldBeeColor.leaf : FieldBeeColor.ink)

                HStack(spacing: 8) {
                    if let season = field.season {
                        Text(season)
                            .font(.caption2)
                            .foregroundColor(FieldBeeColor.slate)
                    }
                    if let crop = field.cropType {
                        Text(crop)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(FieldBeeColor.leaf.opacity(0.18))
                            .cornerRadius(4)
                    }
                    if let area = field.areaHectares {
                        Text(String(format: "%.2f ha", area))
                            .font(.caption2)
                            .foregroundColor(FieldBeeColor.slate)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(FieldBeeColor.leaf)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: ISOTask
    let isActive: Bool

    var body: some View {
        HStack {
            Image(systemName: task.taskType.systemImage)
                .foregroundColor(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.subheadline)
                    .foregroundColor(isActive ? FieldBeeColor.leaf : FieldBeeColor.ink)

                HStack(spacing: 8) {
                    Text(task.taskType.displayName)
                        .font(.caption2)
                        .foregroundColor(FieldBeeColor.slate)

                    StatusBadge(status: task.status)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "bolt.fill")
                    .foregroundColor(FieldBeeColor.leaf)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch task.status {
        case .pending: return FieldBeeColor.slate
        case .inProgress: return FieldBeeColor.leaf
        case .paused: return FieldBeeColor.sun
        case .completed: return FieldBeeColor.soil
        case .cancelled: return .red
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .pending: return FieldBeeColor.slate
        case .inProgress: return FieldBeeColor.leaf
        case .paused: return FieldBeeColor.sun
        case .completed: return FieldBeeColor.soil
        case .cancelled: return .red
        }
    }
}

// MARK: - New Farm Sheet

struct NewFarmSheet: View {
    @ObservedObject var manager: FieldTaskManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var address = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Farm Details")) {
                    TextField("Farm Name", text: $name)
                    TextField("Address (optional)", text: $address)
                }
            }
            .navigationTitle("New Farm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if let farm = manager.createFarm(
                            name: name,
                            address: address.isEmpty ? nil : address
                        ) {
                            manager.selectFarm(farm)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - New Field Sheet

struct NewFieldSheet: View {
    @ObservedObject var manager: FieldTaskManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var season = ""
    @State private var cropType = ""

    private let cropTypes = ["Corn", "Wheat", "Soybeans", "Cotton", "Alfalfa", "Barley", "Oats", "Rice", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Field Details")) {
                    TextField("Field Name", text: $name)
                    TextField("Season (e.g., 2025 Spring)", text: $season)
                    Picker("Crop Type", selection: $cropType) {
                        Text("Select...").tag("")
                        ForEach(cropTypes, id: \.self) { crop in
                            Text(crop).tag(crop)
                        }
                    }
                }

                Section(header: Text("Note")) {
                    Text("After creating the field, use the 'Field' button in the guidance view to draw the boundary.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        _ = manager.createPartfield(
                            name: name,
                            season: season.isEmpty ? nil : season,
                            cropType: cropType.isEmpty ? nil : cropType
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - New Task Sheet

struct NewTaskSheet: View {
    @ObservedObject var manager: FieldTaskManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var taskType: TaskType = .other
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Name", text: $name)

                    Picker("Task Type", selection: $taskType) {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }

                    TextField("Notes (optional)", text: $notes)
                }

                if let field = manager.selectedPartfield {
                    Section(header: Text("Field")) {
                        HStack {
                            Image(systemName: "square.dashed")
                                .foregroundColor(.green)
                            Text(field.name)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if let task = manager.createTask(
                            name: name,
                            taskType: taskType,
                            notes: notes.isEmpty ? nil : notes
                        ) {
                            // Optionally auto-start the task
                            // manager.startTask(task)
                            _ = task // Suppress unused warning
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FieldTaskView()
    }
}
