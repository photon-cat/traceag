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

struct GuidanceView: View {
    @StateObject private var model = GuidanceViewModel()
    @State private var scene = AgGuidanceScene()
    @State private var showControlDrawer = false
    @State private var showPositionDetails = false
    @State private var dragStart: CGPoint?
    @State private var zoomStart: Double?
    @State private var rotationStart: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SceneView(
                    scene: scene,
                    pointOfView: scene.cameraNode,
                    options: []
                )
                .ignoresSafeArea()
                .gesture(sceneGestures)

                VStack(spacing: 12) {
                    topHud
                        .padding(.top, max(geometry.safeAreaInsets.top, 12))
                        .padding(.horizontal, 12)

                    statusCard

                    Spacer()

                    HStack(alignment: .bottom) {
                        scaleIndicator
                        Spacer()
                        cameraModeToggle
                    }
                    .padding(.horizontal, 16)

                    bottomHud
                        .padding(.horizontal, 12)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 12)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            model.scene = scene
            scene.state = model
            model.startSimulation()
        }
        .onDisappear {
            model.stopSimulation()
        }
        .sheet(isPresented: $showControlDrawer) {
            GuidanceControlDrawer(model: model)
        }
    }

    private var topHud: some View {
        HStack(spacing: 12) {
            hudSegmented(title: "View", selection: $model.viewMode, options: ViewMode.allCases)
                .onChange(of: model.viewMode) { _, newValue in
                    model.updateViewMode(newValue)
                }

            hudSegmented(title: "Orientation", selection: $model.headingMode, options: HeadingMode.allCases)

            hudSegmented(title: "Base", selection: $model.backgroundMode, options: BackgroundMode.allCases)
                .onChange(of: model.backgroundMode) { _, newValue in
                    model.updateBackgroundMode(newValue)
                }

            if model.positionSourceType == .simulator {
                Text("SIM")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func hudSegmented<T: Hashable & RawRepresentable>(
        title: String,
        selection: Binding<T>,
        options: [T]
    ) -> some View where T.RawValue == String {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .font(.caption)
        .frame(minWidth: 90)
    }

    private var statusCard: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("↔")
                    .font(.headline)
                Text(String(format: "%.2f m", abs(model.crossTrackError)))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }

            Text(String(format: "Δψ %.1f°", model.headingError * 180 / .pi))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(model.controlMode == .autoFollow ? "AUTO" : "MANUAL") • GUIDANCE \(model.implementActive ? "ON" : "OFF")")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var scaleIndicator: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Int(scaleMeters)) m")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 80, height: 3)
                .clipShape(Capsule())
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var cameraModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.isFreeCamera.toggle()
                if !model.isFreeCamera {
                    model.freeCameraCenterX = model.rearAxleX
                    model.freeCameraCenterZ = model.rearAxleZ
                    model.freeCameraHeading = 0
                } else {
                    model.freeCameraCenterX = model.rearAxleX
                    model.freeCameraCenterZ = model.rearAxleZ
                }
            }
        } label: {
            Image(systemName: model.isFreeCamera ? "camera.viewfinder" : "location.north.circle")
                .font(.title3)
                .foregroundColor(.white)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var bottomHud: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                positionChip
                Spacer()
                Button {
                    showControlDrawer.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button {
                    model.setABPoint()
                } label: {
                    Label(model.abPointState.rawValue, systemImage: abButtonIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(abButtonColor)

                Button {
                    model.implementActive.toggle()
                } label: {
                    Label(model.implementActive ? "Coverage On" : "Coverage Off", systemImage: "paintbrush")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    model.clearCoverage()
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .buttonStyle(.bordered)

                if model.positionSourceType == .simulator {
                    Button {
                        showControlDrawer.toggle()
                    } label: {
                        Label("Sim", systemImage: "gamecontroller")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var positionChip: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showPositionDetails.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(positionSummary)
                    .font(.caption.bold())
                if showPositionDetails {
                    Text(String(format: "Lat %.5f", model.vehicleCoordinate.latitude))
                        .font(.caption2)
                    Text(String(format: "Lon %.5f", model.vehicleCoordinate.longitude))
                        .font(.caption2)
                    Text(String(format: "Alt %.1f m", model.gnssAltitude))
                        .font(.caption2)
                    Text(String(format: "±%.1f m", model.gnssAccuracy))
                        .font(.caption2)
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var positionSummary: String {
        if model.positionSourceType == .simulator {
            return String(format: "SIM • %.1f mph", model.vehicleSpeed * 2.237)
        }
        if model.gnssAccuracy > 0 && model.gnssAccuracy < 1.0 {
            return String(format: "RTK FIX • %.1f mph", model.vehicleSpeed * 2.237)
        }
        return String(format: "GPS • %.1f mph", model.vehicleSpeed * 2.237)
    }

    private var abButtonIcon: String {
        switch model.abPointState {
        case .none: return "mappin.and.ellipse"
        case .aSet: return "mappin.and.ellipse"
        case .complete: return "arrow.counterclockwise"
        }
    }

    private var abButtonColor: Color {
        switch model.abPointState {
        case .none: return .green
        case .aSet: return .orange
        case .complete: return .blue
        }
    }

    private var scaleMeters: Double {
        let raw = model.viewMode == .topDown2D ? model.cameraZoom / 6 : model.cameraDistance
        return max(5, min(50, raw))
    }

    private var sceneGestures: some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                guard model.isFreeCamera else { return }
                let scale = model.viewMode == .topDown2D ? model.cameraZoom / 250 : model.cameraDistance / 80
                if dragStart == nil {
                    dragStart = CGPoint(x: model.freeCameraCenterX, y: model.freeCameraCenterZ)
                }
                let start = dragStart ?? .zero
                model.freeCameraCenterX = Double(start.x) - Double(value.translation.width) * scale
                model.freeCameraCenterZ = Double(start.y) + Double(value.translation.height) * scale
            }
            .onEnded { _ in
                dragStart = nil
            }

        let magnify = MagnificationGesture()
            .onChanged { value in
                if zoomStart == nil {
                    zoomStart = model.viewMode == .topDown2D ? model.cameraZoom : model.cameraDistance
                }
                let start = zoomStart ?? 60
                let newValue = start / Double(value)
                if model.viewMode == .topDown2D {
                    model.cameraZoom = min(160, max(30, newValue))
                } else {
                    model.cameraDistance = min(60, max(18, newValue))
                }
            }
            .onEnded { _ in
                zoomStart = nil
            }

        let rotate = RotationGesture()
            .onChanged { value in
                guard model.isFreeCamera, model.headingMode == .northUp else { return }
                if rotationStart == nil {
                    rotationStart = model.freeCameraHeading
                }
                let start = rotationStart ?? 0
                model.freeCameraHeading = start + value.radians
            }
            .onEnded { _ in
                rotationStart = nil
            }

        let doubleTap = TapGesture(count: 2)
            .onEnded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    model.isFreeCamera = false
                    model.freeCameraCenterX = model.rearAxleX
                    model.freeCameraCenterZ = model.rearAxleZ
                    model.freeCameraHeading = 0
                }
            }

        return drag.simultaneously(with: magnify)
            .simultaneously(with: rotate)
            .simultaneously(with: doubleTap)
    }
}

private struct GuidanceControlDrawer: View {
    @ObservedObject var model: GuidanceViewModel

    var body: some View {
        NavigationStack {
            List {
                if model.positionSourceType == .simulator {
                    Section("Simulator Controls") {
                        simulatorSpeed
                        simulatorTurn
                    }
                }

                Section("Debug") {
                    Toggle("Show debug markers", isOn: $model.showDebugMarkers)
                    Toggle("Heading tail", isOn: $model.showHeadingTail)
                }

                Section("Implement") {
                    Stepper("Width \(model.implementWidth, specifier: "%.1f") m", value: $model.implementWidth, in: 2...18, step: 0.5)
                }
            }
            .navigationTitle("Controls")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var simulatorSpeed: some View {
        HStack {
            Text("Speed")
            Spacer()
            Button {
                model.decreaseSimulatorSpeed()
            } label: {
                Image(systemName: "minus.circle")
            }
            Text(String(format: "%.1f m/s", model.simulatorSpeed))
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 70)
            Button {
                model.increaseSimulatorSpeed()
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }

    private var simulatorTurn: some View {
        HStack {
            Text("Turn")
            Spacer()
            Image(systemName: "arrow.turn.up.left")
                .font(.title3)
                .padding(8)
                .background(Circle().fill(Color.blue))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            model.simulatorTurnLeft()
                        }
                        .onEnded { _ in
                            model.simulatorReleaseTurn()
                        }
                )

            Image(systemName: "arrow.turn.up.right")
                .font(.title3)
                .padding(8)
                .background(Circle().fill(Color.blue))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            model.simulatorTurnRight()
                        }
                        .onEnded { _ in
                            model.simulatorReleaseTurn()
                        }
                )
        }
        .foregroundColor(.white)
    }
}

#Preview {
    GuidanceView()
}
