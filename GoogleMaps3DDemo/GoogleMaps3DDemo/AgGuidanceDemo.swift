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
import SceneKit

struct AgGuidanceDemo: View {
    @StateObject private var state = AgGuidanceState()
    @State private var scene = AgGuidanceScene()
    @State private var showSettings = false
    @State private var showSimulatorDrawer = false
    @State private var showFieldTaskView = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // SceneKit View
                SceneView(
                    scene: scene,
                    pointOfView: scene.cameraNode,
                    options: []
                )
                .ignoresSafeArea()

                // HUD Overlay
                VStack(spacing: 0) {
                    // Top HUD strip
                    TopHUDStrip(state: state)
                        .padding(.horizontal, 12)
                        .padding(.top, max(geometry.safeAreaInsets.top, 59) + 8)

                    // Status card (guidance errors)
                    StatusCard(state: state)
                        .padding(.top, 8)

                    Spacer()

                    // Bottom section
                    bottomSection(geometry: geometry)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            state.scene = scene
            scene.state = state
            state.startSimulation()
        }
        .onDisappear {
            state.stopSimulation()
        }
        .sheet(isPresented: $showSettings) {
            AgGuidanceSettings(state: state)
        }
        .sheet(isPresented: $showFieldTaskView) {
            NavigationStack {
                FieldTaskView(showsDoneButton: true)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private func bottomSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            // Coordinate readout and GNSS status
            HStack(spacing: 8) {
                CoordinateReadout(
                    state: state,
                    isExpanded: $state.isCoordinateReadoutExpanded
                )
                Spacer()
            }
            .padding(.horizontal, 12)

            // Simulator drawer (collapsible)
            if state.positionSourceType == .simulator {
                SimulatorDrawer(
                    state: state,
                    isExpanded: $showSimulatorDrawer
                )
                .padding(.horizontal, 12)
            }

            // Primary action buttons
            BottomActionRow(
                state: state,
                showSettings: $showSettings,
                showSimulatorDrawer: $showSimulatorDrawer
            )

            // Manual steering controls
            if state.controlMode == .manual {
                SteeringControls(state: state)
                    .padding(.vertical, 8)
            }

            // Stats bar
            statsBar
                .padding(.horizontal, 12)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 12) {
            // Speed
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.caption)
                Text(String(format: "%.1f m/s", state.vehicleSpeed))
            }

            Spacer()

            // Current line
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                Text("Line \(state.currentLineIndex)")
            }

            Spacer()

            // Implement status
            HStack(spacing: 4) {
                Circle()
                    .fill(state.implementActive ? GuidanceHUDColors.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(state.implementActive ? "Paint" : "Off")
                    .font(.caption)
            }

            Spacer()

            // Coverage percentage
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption)
                Text(String(format: "%.1f%%", state.coveragePercent))
            }
        }
        .font(GuidanceHUDStyles.smallReadout)
        .foregroundColor(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .hudPanel()
    }
}

#Preview {
    AgGuidanceDemo()
}
