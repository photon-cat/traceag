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
    @State private var showSimulatorControls = false
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

                // Overlay UI
                VStack(spacing: 0) {
                    // Top control bar
                    topControls
                        .padding(.horizontal, 8)
                        .padding(.top, max(geometry.safeAreaInsets.top, 59) + 8)

                    // Cross-track error indicator
                    crossTrackIndicator
                        .padding(.top, 8)

                    Spacer()

                    // Coordinate and GNSS status display
                    HStack(spacing: 8) {
                        coordinateDisplay
                        gnssStatusIndicator
                    }
                    .padding(.horizontal, 8)

                    // Simulator controls button and panel
                    if state.positionSourceType == .simulator {
                        simulatorControlsSection
                            .padding(.horizontal, 8)
                    }

                    // Action buttons
                    actionButtons
                        .padding(.vertical, 8)

                    // Steering controls (manual mode only)
                    if state.controlMode == .manual {
                        steeringControls
                            .padding(.vertical, 8)
                    }

                    // Stats bar
                    statsBar
                        .padding(.horizontal, 8)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
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
            FieldTaskView()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Top Controls

    private var topControls: some View {
        VStack(spacing: 8) {
            // First row: View and Background toggles
            HStack(spacing: 8) {
                // View mode toggle
                Picker("View", selection: $state.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 70, maxWidth: 80)
                .onChange(of: state.viewMode) { _, newValue in
                    state.updateViewMode(newValue)
                }

                Spacer()

                // Heading mode toggle
                Picker("Heading", selection: $state.headingMode) {
                    Text("N↑").tag(HeadingMode.northUp)
                    Text("H↑").tag(HeadingMode.headingUp)
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 70, maxWidth: 80)

                Spacer()

                // Background toggle
                Picker("Background", selection: $state.backgroundMode) {
                    ForEach(BackgroundMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 110, maxWidth: 130)
                .onChange(of: state.backgroundMode) { _, newValue in
                    state.updateBackgroundMode(newValue)
                }
            }

            // Second row: Control mode and Implement toggle
            HStack(spacing: 8) {
                // Control mode toggle
                Picker("Control", selection: $state.controlMode) {
                    ForEach(ControlMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 100, maxWidth: 120)

                Spacer()

                // Implement toggle
                Button(action: {
                    state.implementActive.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: state.implementActive ? "paintbrush.fill" : "paintbrush")
                        Text(state.implementActive ? "ON" : "OFF")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(state.implementActive ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    // MARK: - Cross-Track Error Indicator
    // Indicator shows where the LINE is relative to the vehicle
    // Steer TOWARD the ball to get on line

    private var crossTrackIndicator: some View {
        let error = state.crossTrackError
        let maxError: Double = 5.0  // Max display range in meters
        let clampedError = max(-maxError, min(maxError, error))
        // INVERT: negative position means line is to the RIGHT of indicator
        // So the ball shows where the LINE is - steer toward it
        let position = -clampedError / maxError  // Inverted: ball shows line position

        return VStack(spacing: 4) {
            // Visual bar
            GeometryReader { geo in
                ZStack {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))

                    // Center line (vehicle position)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3)

                    // Ball indicator shows where the LINE is - steer toward it
                    Circle()
                        .fill(abs(error) < 0.5 ? Color.green : (abs(error) < 2 ? Color.yellow : Color.red))
                        .frame(width: 16, height: 16)
                        .offset(x: CGFloat(position) * (geo.size.width / 2 - 8))
                }
            }
            .frame(height: 24)
            .frame(maxWidth: 200)

            // Text display - shows direction to steer
            HStack {
                Text(position > 0 ? "→" : "←")
                    .font(.caption)
                    .foregroundColor(position > 0 ? .orange : .blue)
                Text(String(format: "%.2f m", abs(error)))
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    // MARK: - Coordinate Display

    private var coordinateDisplay: some View {
        let coord = state.vehicleCoordinate
        return HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
            Text(String(format: "%.5f° N, %.5f° W",
                        coord.latitude,
                        abs(coord.longitude)))
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    // MARK: - GNSS Status Indicator

    private var gnssStatusIndicator: some View {
        let accuracy = state.gnssAccuracy
        let updateRate = state.gnssUpdateRate
        let isExternal = state.isExternalGNSS
        let sourceType = state.positionSourceType

        // Determine status color based on accuracy
        let statusColor: Color = {
            if sourceType == .simulator {
                return .blue
            } else if accuracy < 0 {
                return .gray
            } else if accuracy < 1.0 {
                return .green  // RTK/Excellent
            } else if accuracy < 2.5 {
                return .green.opacity(0.8)  // DGPS/Good
            } else if accuracy < 5.0 {
                return .yellow  // Standard
            } else {
                return .red  // Poor
            }
        }()

        #if os(iOS)
        let selectedDeviceName = GPSDeviceManager.shared.selectedDevice?.displayName ?? "GPS"
        #else
        let selectedDeviceName = "GPS"
        #endif

        return HStack(spacing: 8) {
            // GNSS source indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            if sourceType == .simulator {
                Text("SIM")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            } else {
                // Device name (truncated)
                Text(selectedDeviceName.prefix(12))
                    .font(.caption)
                    .foregroundColor(isExternal ? .green : .primary)
                    .lineLimit(1)

                // Accuracy
                if accuracy >= 0 {
                    Text(String(format: "±%.1fm", accuracy))
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text("No Fix")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Update rate
                if updateRate > 0 {
                    Text(String(format: "%.0fHz", updateRate))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Fields & Tasks management
            Button(action: {
                showFieldTaskView = true
            }) {
                Label("Tasks", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            // Demo boundary button (like 'B' key in pysim)
            Button(action: {
                state.createDemoBoundary()
            }) {
                Label("Field", systemImage: "square.dashed")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            // Set AB button - label changes based on state
            Button(action: {
                state.setABPoint()
            }) {
                Label(state.abPointState.rawValue, systemImage: abButtonIcon)
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(abButtonColor)

            // Clear button
            Button(action: {
                state.clearCoverage()
            }) {
                Label("Clear", systemImage: "xmark.circle")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            // Settings button
            Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
        }
    }

    private var abButtonIcon: String {
        switch state.abPointState {
        case .none: return "mappin.and.ellipse"
        case .aSet: return "mappin.and.ellipse"
        case .complete: return "arrow.counterclockwise"
        }
    }

    private var abButtonColor: Color {
        switch state.abPointState {
        case .none: return .green
        case .aSet: return .orange
        case .complete: return .blue
        }
    }

    // MARK: - Steering Controls

    private var steeringControls: some View {
        HStack(spacing: 50) {
            steeringButton(direction: -1.0, icon: "arrow.turn.up.left")
            steeringButton(direction: 1.0, icon: "arrow.turn.up.right")
        }
    }

    private func steeringButton(direction: Double, icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 70, height: 70)
            .background(
                Circle()
                    .fill(state.steeringValue == direction ? Color.blue : Color.blue.opacity(0.7))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        state.steeringValue = direction
                    }
                    .onEnded { _ in
                        state.steeringValue = 0
                    }
            )
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
                    .fill(state.implementActive ? Color.green : Color.gray)
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
        .font(.system(.subheadline, design: .monospaced))
        .foregroundColor(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    // MARK: - Simulator Controls Section

    private var simulatorControlsSection: some View {
        VStack(spacing: 8) {
            // Toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSimulatorControls.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                    Text("Simulator Controls")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: showSimulatorControls ? "chevron.up" : "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)

            // Expandable controls panel
            if showSimulatorControls {
                simulatorControlsPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var simulatorControlsPanel: some View {
        VStack(spacing: 12) {
            // Speed controls
            HStack(spacing: 16) {
                Text("Speed")
                    .font(.caption.bold())
                    .frame(width: 50, alignment: .leading)

                Button(action: {
                    state.decreaseSimulatorSpeed()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }

                Text(String(format: "%.1f m/s", state.simulatorSpeed))
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 70)

                Button(action: {
                    state.increaseSimulatorSpeed()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }

                Spacer()
            }

            Divider()

            // Turn controls
            HStack(spacing: 20) {
                Text("Turn")
                    .font(.caption.bold())
                    .frame(width: 50, alignment: .leading)

                // Left turn button
                Image(systemName: "arrow.turn.up.left")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.blue))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                state.simulatorTurnLeft()
                            }
                            .onEnded { _ in
                                state.simulatorReleaseTurn()
                            }
                    )

                Spacer()

                // Right turn button
                Image(systemName: "arrow.turn.up.right")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.blue))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                state.simulatorTurnRight()
                            }
                            .onEnded { _ in
                                state.simulatorReleaseTurn()
                            }
                    )

                Spacer()
            }

            // Current heading display
            HStack {
                Text("Heading")
                    .font(.caption.bold())
                    .frame(width: 50, alignment: .leading)
                Text(String(format: "%.1f°", state.vehicleHeading * 180 / .pi))
                    .font(.system(.caption, design: .monospaced))
                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

#Preview {
    AgGuidanceDemo()
}
