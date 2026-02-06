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

/// Expandable coordinate readout - collapsed by default
struct CoordinateReadout: View {
    @ObservedObject var state: AgGuidanceState
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed view (always visible)
            collapsedView
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            // Expanded details
            if isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .hudPanel()
    }

    // MARK: - Collapsed View

    private var collapsedView: some View {
        HStack(spacing: 8) {
            // Source indicator
            sourceIndicator

            // Brief status
            if state.positionSourceType == .simulator {
                Text("SIM")
                    .font(.caption.bold())
                    .foregroundColor(GuidanceHUDColors.simulator)
            } else {
                Text(fixTypeText)
                    .font(.caption.bold())
                    .foregroundColor(fixTypeColor)
            }

            // Speed
            Text(String(format: "%.1f m/s", state.vehicleSpeed))
                .font(GuidanceHUDStyles.smallReadout)
                .foregroundColor(.secondary)

            // Expand indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, GuidanceHUDStyles.paddingCompact)
        .padding(.vertical, 6)
    }

    private var sourceIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        if state.positionSourceType == .simulator {
            return GuidanceHUDColors.simulator
        }
        let accuracy = state.gnssAccuracy
        if accuracy < 0 {
            return .gray
        } else if accuracy < 1.0 {
            return .green
        } else if accuracy < 2.5 {
            return .green.opacity(0.8)
        } else if accuracy < 5.0 {
            return .yellow
        } else {
            return .red
        }
    }

    private var fixTypeText: String {
        if state.gnssAccuracy < 0 {
            return "NO FIX"
        } else if state.gnssAccuracy < 0.1 {
            return "RTK FIX"
        } else if state.gnssAccuracy < 1.0 {
            return "RTK"
        } else if state.gnssAccuracy < 2.5 {
            return "DGPS"
        } else {
            return "GPS"
        }
    }

    private var fixTypeColor: Color {
        if state.gnssAccuracy < 0 {
            return .red
        } else if state.gnssAccuracy < 1.0 {
            return .green
        } else if state.gnssAccuracy < 2.5 {
            return .green.opacity(0.8)
        } else {
            return .yellow
        }
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            // Latitude
            coordinateRow(label: "Lat", value: formatLatitude(state.vehicleCoordinate.latitude))

            // Longitude
            coordinateRow(label: "Lon", value: formatLongitude(state.vehicleCoordinate.longitude))

            // Accuracy
            if state.positionSourceType != .simulator && state.gnssAccuracy >= 0 {
                coordinateRow(label: "Acc", value: String(format: "±%.2f m", state.gnssAccuracy))
            }

            // Update rate
            if state.gnssUpdateRate > 0 {
                coordinateRow(label: "Rate", value: String(format: "%.0f Hz", state.gnssUpdateRate))
            }

            // Heading
            coordinateRow(label: "Hdg", value: String(format: "%.1f°", state.vehicleHeading * 180 / .pi))
        }
        .padding(.horizontal, GuidanceHUDStyles.paddingCompact)
        .padding(.bottom, 8)
    }

    private func coordinateRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(GuidanceHUDStyles.smallReadout)
        }
    }

    private func formatLatitude(_ lat: Double) -> String {
        let direction = lat >= 0 ? "N" : "S"
        return String(format: "%.6f° %@", abs(lat), direction)
    }

    private func formatLongitude(_ lon: Double) -> String {
        let direction = lon >= 0 ? "E" : "W"
        return String(format: "%.6f° %@", abs(lon), direction)
    }
}

// MARK: - GNSS Status Badge

struct GNSSStatusBadge: View {
    @ObservedObject var state: AgGuidanceState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if state.positionSourceType == .simulator {
                Text("SIM")
                    .font(.caption.bold())
                    .foregroundColor(GuidanceHUDColors.simulator)
            } else {
                Text(accuracyText)
                    .font(GuidanceHUDStyles.smallReadout)

                if state.gnssUpdateRate > 0 {
                    Text(String(format: "%.0fHz", state.gnssUpdateRate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .hudCompactPanel()
    }

    private var statusColor: Color {
        if state.positionSourceType == .simulator {
            return GuidanceHUDColors.simulator
        }
        let accuracy = state.gnssAccuracy
        if accuracy < 0 { return .gray }
        if accuracy < 1.0 { return .green }
        if accuracy < 5.0 { return .yellow }
        return .red
    }

    private var accuracyText: String {
        if state.gnssAccuracy < 0 {
            return "No Fix"
        }
        return String(format: "±%.1fm", state.gnssAccuracy)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            CoordinateReadout(
                state: AgGuidanceState(),
                isExpanded: .constant(false)
            )

            CoordinateReadout(
                state: AgGuidanceState(),
                isExpanded: .constant(true)
            )

            GNSSStatusBadge(state: AgGuidanceState())
        }
        .padding()
    }
}
