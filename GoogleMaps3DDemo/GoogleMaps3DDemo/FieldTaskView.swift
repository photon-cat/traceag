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

    var body: some View {
        NavigationView {
            List {
                // Farm Section
                Section(header: Text("Farm")) {
                    if let farm = manager.selectedFarm {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.brown)
                            Text(farm.name)
                                .font(.headline)
                            Spacer()
                            Text("\(manager.partfields.count) fields")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: { showNewFarmSheet = true }) {
                            Label("Create Farm", systemImage: "plus.circle")
                        }
                    }
                }

                // Fields Section
                Section(header: HStack {
                    Text("Fields")
                    Spacer()
                    Button(action: { showNewFieldSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                    .disabled(manager.selectedFarm == nil)
                }) {
                    if manager.partfields.isEmpty {
                        Text("No fields yet")
                            .foregroundColor(.secondary)
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

                // Tasks Section (only show if field selected)
                if let selectedField = manager.selectedPartfield {
                    Section(header: HStack {
                        Text("Tasks for \(selectedField.name)")
                        Spacer()
                        Button(action: { showNewTaskSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }) {
                        if manager.tasks.isEmpty {
                            Text("No tasks yet")
                                .foregroundColor(.secondary)
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
                                            .tint(.green)
                                        } else if task.status == .inProgress {
                                            Button {
                                                manager.pauseTask(task)
                                            } label: {
                                                Label("Pause", systemImage: "pause.fill")
                                            }
                                            .tint(.orange)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        if task.status != .completed && task.status != .cancelled {
                                            Button {
                                                manager.completeTask(task)
                                            } label: {
                                                Label("Complete", systemImage: "checkmark")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                            }
                            .onDelete(perform: deleteTasks)
                        }
                    }
                }

                // Active Task Summary
                if let activeTask = manager.activeTask {
                    Section(header: Text("Active Task")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: activeTask.taskType.systemImage)
                                    .foregroundColor(.blue)
                                Text(activeTask.name)
                                    .font(.headline)
                            }
                            Text("Status: In Progress")
                                .font(.caption)
                                .foregroundColor(.green)
                            if let coverage = getCoverageForActiveTask() {
                                Text("Coverage: \(coverage) cells")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Fields & Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                .foregroundColor(isSelected ? .green : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(field.name)
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .green : .primary)

                HStack(spacing: 8) {
                    if let season = field.season {
                        Text(season)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let crop = field.cropType {
                        Text(crop)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if let area = field.areaHectares {
                        Text(String(format: "%.2f ha", area))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
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
                    .foregroundColor(isActive ? .blue : .primary)

                HStack(spacing: 8) {
                    Text(task.taskType.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    StatusBadge(status: task.status)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch task.status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .paused: return .orange
        case .completed: return .green
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
        case .pending: return .gray
        case .inProgress: return .blue
        case .paused: return .orange
        case .completed: return .green
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
    FieldTaskView()
}
