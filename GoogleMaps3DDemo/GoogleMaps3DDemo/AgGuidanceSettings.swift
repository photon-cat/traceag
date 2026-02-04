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

struct AgGuidanceSettings: View {
    @ObservedObject var state: AgGuidanceState
    @Environment(\.dismiss) var dismiss

    @State private var lineSpacingText: String = ""
    @State private var headingDegreesText: String = ""
    @State private var speedText: String = ""
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""

    // Machine Profile
    @State private var machineName: String = ""
    @State private var wheelbase: String = ""
    @State private var maxSteerAngle: String = ""
    @State private var hitchOffset: String = ""
    @State private var antennaHeight: String = ""
    @State private var antennaLateralOffset: String = ""
    @State private var antennaLongOffset: String = ""

    // Implement Profile
    @State private var implementName: String = ""
    @State private var isPivoting: Bool = false
    @State private var centerOfRotationOffset: String = ""
    @State private var workPointOffset: String = ""
    @State private var workAreaWidth: String = ""

    var body: some View {
        NavigationView {
            Form {
                // Machine Profile Section
                Section(header: Text("Machine Profile")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Machine", text: $machineName)
                            .multilineTextAlignment(.trailing)
                    }
                    NumberRow(label: "Wheelbase", value: $wheelbase, unit: "m")
                    NumberRow(label: "Max Steer Angle", value: $maxSteerAngle, unit: "°")
                    NumberRow(label: "Hitch Offset", value: $hitchOffset, unit: "m")
                    NumberRow(label: "Antenna Height", value: $antennaHeight, unit: "m")
                    NumberRow(label: "Antenna Lateral", value: $antennaLateralOffset, unit: "m")
                    NumberRow(label: "Antenna Long.", value: $antennaLongOffset, unit: "m")
                }

                // Implement Profile Section
                Section(header: Text("Implement Profile")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Implement", text: $implementName)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Pivoting", isOn: $isPivoting)
                    if isPivoting {
                        NumberRow(label: "Center of Rotation", value: $centerOfRotationOffset, unit: "m")
                    }
                    NumberRow(label: "Work Point Offset", value: $workPointOffset, unit: "m")
                    NumberRow(label: "Work Area Width", value: $workAreaWidth, unit: "m")
                }

                // Position Source Section
                Section(header: Text("Position Source")) {
                    Picker("Source", selection: $state.positionSourceType) {
                        ForEach(PositionSourceType.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }

                    if state.positionSourceType == .simulator {
                        NumberRow(label: "Speed", value: $speedText, unit: "m/s")

                        HStack {
                            Text("Latitude")
                            Spacer()
                            TextField("38.06517", text: $latitudeText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text("°")
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                        }

                        HStack {
                            Text("Longitude")
                            Spacer()
                            TextField("-79.05179", text: $longitudeText)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text("°")
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                        }
                    }

                    if state.positionSourceType == .gnss {
                        // GNSS Status Display
                        HStack {
                            Text("Status")
                            Spacer()
                            if let status = state.gnssStatus {
                                Text(status.sourceName)
                                    .foregroundColor(status.isExternalGNSS ? .green : .secondary)
                            } else {
                                Text("Waiting...")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Accuracy")
                            Spacer()
                            if state.gnssAccuracy >= 0 {
                                Text(String(format: "±%.2f m", state.gnssAccuracy))
                                    .foregroundColor(state.gnssAccuracy < 2.0 ? .green : .secondary)
                            } else {
                                Text("No fix")
                                    .foregroundColor(.red)
                            }
                        }

                        HStack {
                            Text("Update Rate")
                            Spacer()
                            Text(String(format: "%.1f Hz", state.gnssUpdateRate))
                                .foregroundColor(state.gnssUpdateRate >= 5 ? .green : .secondary)
                        }

                        if state.isExternalGNSS {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("External GNSS Detected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // GPS Device Selection Section
                #if os(iOS)
                if state.positionSourceType == .gnss {
                    Section(header: Text("GPS Device")) {
                        // Device picker
                        let devices = GPSDeviceManager.shared.connectedDevices

                        if devices.isEmpty {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Scanning for devices...")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(devices) { device in
                                Button(action: {
                                    GPSDeviceManager.shared.selectDevice(device.id)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.displayName)
                                                .foregroundColor(.primary)
                                            if device.id != "internal" {
                                                Text(device.modelNumber.isEmpty ? "External GPS" : device.modelNumber)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if GPSDeviceManager.shared.selectedDeviceId == device.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }

                                        // Connection status indicator
                                        Circle()
                                            .fill(device.isConnected ? Color.green : Color.gray)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }

                            // Refresh button
                            Button(action: {
                                GPSDeviceManager.shared.refreshConnectedDevices()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh Devices")
                                }
                            }
                        }
                    }

                    // External GNSS Info
                    Section(header: Text("About External GNSS")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Supported Devices:")
                                .font(.subheadline.bold())
                            Text("• Garmin GLO 2 (Bluetooth)")
                                .font(.caption)
                            Text("• Bad Elf GPS Pro+ (Bluetooth)")
                                .font(.caption)
                            Text("• Dual XGPS150/160 (Bluetooth)")
                                .font(.caption)

                            Divider()

                            Text("Setup:")
                                .font(.subheadline.bold())
                                .padding(.top, 4)
                            Text("1. Pair device in iOS Settings → Bluetooth")
                                .font(.caption)
                            Text("2. Turn on external receiver")
                                .font(.caption)
                            Text("3. Select device above")
                                .font(.caption)

                            Divider()

                            Text("Benefits:")
                                .font(.subheadline.bold())
                                .padding(.top, 4)
                            Text("• Sub-meter accuracy with SBAS")
                                .font(.caption)
                            Text("• Up to 10Hz update rate")
                                .font(.caption)
                            Text("• Better signal in challenging environments")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                #endif

                // AB Line Section
                Section(header: Text("AB Line")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(abLineStatusText)
                            .foregroundColor(.secondary)
                    }

                    if state.abLine != nil {
                        NumberRow(label: "Heading", value: $headingDegreesText, unit: "°")

                        if let length = state.abLine?.length {
                            HStack {
                                Text("Length")
                                Spacer()
                                Text(String(format: "%.1f m", length))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Picker("Lines Direction", selection: $state.linesDirection) {
                        Text("Left").tag(LinesDirection.left)
                        Text("Right").tag(LinesDirection.right)
                        Text("Both").tag(LinesDirection.both)
                    }

                    NumberRow(label: "Line Spacing", value: $lineSpacingText, unit: "m")
                }

                // Apply Button
                Section {
                    Button("Apply Settings") {
                        applySettings()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }

    private var abLineStatusText: String {
        switch state.abPointState {
        case .none:
            return "Not set"
        case .aSet:
            return "A point set, waiting for B"
        case .complete:
            return "A-B line complete"
        }
    }

    private func loadCurrentValues() {
        // Guidance
        lineSpacingText = String(format: "%.1f", state.guidanceSpacing)
        headingDegreesText = String(format: "%.1f", state.abHeadingDegrees)

        // Simulator
        speedText = String(format: "%.1f", state.simulatorSpeed)
        latitudeText = String(format: "%.5f", state.simulatorInitialCoordinate.latitude)
        longitudeText = String(format: "%.5f", state.simulatorInitialCoordinate.longitude)

        // Machine Profile
        let machine = state.vehicleConfig.machine
        machineName = machine.name
        wheelbase = String(format: "%.2f", machine.wheelbase)
        maxSteerAngle = String(format: "%.1f", machine.maxSteerAngle)
        hitchOffset = String(format: "%.2f", machine.hitchOffset)
        antennaHeight = String(format: "%.2f", machine.antennaHeight)
        antennaLateralOffset = String(format: "%.2f", machine.antennaLateralOffset)
        antennaLongOffset = String(format: "%.2f", machine.antennaLongOffset)

        // Implement Profile
        let implement = state.vehicleConfig.implement
        implementName = implement.name
        isPivoting = implement.isPivoting
        centerOfRotationOffset = String(format: "%.2f", implement.centerOfRotationOffset)
        workPointOffset = String(format: "%.2f", implement.workPointOffset)
        workAreaWidth = String(format: "%.1f", implement.workAreaWidth)
    }

    private func applySettings() {
        // Guidance
        if let spacing = Double(lineSpacingText), spacing > 0 {
            state.guidanceSpacing = spacing
        }
        if let heading = Double(headingDegreesText) {
            state.abHeadingDegrees = heading
        }

        // Simulator
        if let speed = Double(speedText), speed > 0 {
            state.simulatorSpeed = speed
        }
        if let lat = Double(latitudeText), let lon = Double(longitudeText) {
            state.simulatorInitialCoordinate = .init(latitude: lat, longitude: lon)
        }

        // Machine Profile
        state.vehicleConfig.machine.name = machineName
        if let val = Double(wheelbase), val > 0 { state.vehicleConfig.machine.wheelbase = val }
        if let val = Double(maxSteerAngle), val > 0 { state.vehicleConfig.machine.maxSteerAngle = val }
        if let val = Double(hitchOffset) { state.vehicleConfig.machine.hitchOffset = val }
        if let val = Double(antennaHeight), val >= 0 { state.vehicleConfig.machine.antennaHeight = val }
        if let val = Double(antennaLateralOffset) { state.vehicleConfig.machine.antennaLateralOffset = val }
        if let val = Double(antennaLongOffset) { state.vehicleConfig.machine.antennaLongOffset = val }

        // Implement Profile
        state.vehicleConfig.implement.name = implementName
        state.vehicleConfig.implement.isPivoting = isPivoting
        if let val = Double(centerOfRotationOffset), val >= 0 {
            state.vehicleConfig.implement.centerOfRotationOffset = val
        }
        if let val = Double(workPointOffset), val >= 0 {
            state.vehicleConfig.implement.workPointOffset = val
        }
        if let val = Double(workAreaWidth), val > 0 {
            state.vehicleConfig.implement.workAreaWidth = val
            state.implementWidth = val
        }
    }
}

// MARK: - Helper View

struct NumberRow: View {
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }
}
