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
import GoogleMaps3D

struct OperationsHomeView: View {
    @ObservedObject private var manager = FieldTaskManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                mapPreview
                workflowStatus
                quickActions
                activeTaskCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(FieldBeeColor.mist.ignoresSafeArea())
        .navigationTitle("FieldBee Ops")
    }

    private var header: some View {
        FieldBeeCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Good morning")
                    .font(.caption)
                    .foregroundColor(FieldBeeColor.slate)
                Text("Plan, guide, and execute today's fieldwork.")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(FieldBeeColor.ink)
                HStack(spacing: 12) {
                    FieldBeePill(text: "\(manager.partfields.count) Fields", color: FieldBeeColor.leaf)
                    FieldBeePill(text: "\(manager.tasks.count) Tasks", color: FieldBeeColor.soil)
                }
            }
        }
    }

    private var mapPreview: some View {
        FieldBeeCard {
            VStack(alignment: .leading, spacing: 12) {
                FieldBeeSectionHeader("Live Map", subtitle: "Hybrid view centered on your operation.")
                Map(mode: .hybrid)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private var workflowStatus: some View {
        FieldBeeCard {
            VStack(alignment: .leading, spacing: 12) {
                FieldBeeSectionHeader("Workflow", subtitle: "Where your team is focused today.")
                HStack(alignment: .top, spacing: 16) {
                    statusColumn(title: "Farms", value: manager.selectedFarm?.name ?? "None")
                    statusColumn(title: "Selected Field", value: manager.selectedPartfield?.name ?? "Choose one")
                    statusColumn(title: "Active Task", value: manager.activeTask?.name ?? "Idle")
                }
            }
        }
    }

    private var quickActions: some View {
        FieldBeeCard {
            VStack(alignment: .leading, spacing: 12) {
                FieldBeeSectionHeader("Quick Actions", subtitle: "Jump into the main workflows.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    NavigationLink {
                        FieldTaskView()
                    } label: {
                        actionTile(title: "Fields & Tasks", systemImage: "square.3.layers.3d.down.right")
                    }

                    NavigationLink {
                        AgGuidanceDemo()
                    } label: {
                        actionTile(title: "Guidance Mode", systemImage: "location.north.line")
                    }

                    NavigationLink {
                        DemoCatalogView()
                    } label: {
                        actionTile(title: "Sample Demos", systemImage: "sparkles")
                    }

                    NavigationLink {
                        ContentView()
                    } label: {
                        actionTile(title: "Map Only", systemImage: "globe.americas.fill")
                    }
                }
            }
        }
    }

    private var activeTaskCard: some View {
        FieldBeeCard {
            VStack(alignment: .leading, spacing: 12) {
                FieldBeeSectionHeader("Active Task", subtitle: "Real-time progress and guidance.")
                if let activeTask = manager.activeTask {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: activeTask.taskType.systemImage)
                            .font(.title2)
                            .foregroundColor(FieldBeeColor.leaf)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeTask.name)
                                .font(.headline)
                            Text(activeTask.taskType.displayName)
                                .font(.caption)
                                .foregroundColor(FieldBeeColor.slate)
                        }
                        Spacer()
                        FieldBeePill(text: activeTask.status.displayName, color: FieldBeeColor.leaf)
                    }
                } else {
                    Text("No active tasks yet. Start one from the Fields tab.")
                        .font(.subheadline)
                        .foregroundColor(FieldBeeColor.slate)
                }
            }
        }
    }

    private func statusColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(FieldBeeColor.slate)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(FieldBeeColor.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionTile(title: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(FieldBeeColor.leaf)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(FieldBeeColor.ink)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(12)
        .background(FieldBeeColor.mist)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        OperationsHomeView()
    }
}
