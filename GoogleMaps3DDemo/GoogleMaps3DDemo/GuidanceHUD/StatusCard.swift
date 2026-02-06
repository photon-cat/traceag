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

/// Compact status card showing guidance errors and mode
struct StatusCard: View {
    @ObservedObject var state: AgGuidanceState

    var body: some View {
        HStack(spacing: 20) {
            // Lateral error (large)
            lateralErrorView

            verticalDivider

            // Heading error (smaller)
            headingErrorView

            verticalDivider

            // Mode indicators
            modeIndicators
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .hudPanel()
    }

    // MARK: - Lateral Error

    private var lateralErrorView: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.left.and.right")
                .font(.caption)
            Text(formatLateralError(state.crossTrackError))
                .font(GuidanceHUDStyles.largeReadout)
        }
        .foregroundColor(lateralErrorColor)
    }

    private var lateralErrorColor: Color {
        GuidanceHUDColors.lateralErrorColor(state.crossTrackError)
    }

    private func formatLateralError(_ error: Double) -> String {
        let direction = error > 0 ? "R" : "L"
        let absError = abs(error)
        if absError < 10 {
            return String(format: "%@ %.2f m", direction, absError)
        } else {
            return String(format: "%@ %.1f m", direction, absError)
        }
    }

    // MARK: - Heading Error

    private var headingErrorView: some View {
        HStack(spacing: 4) {
            Text("Δψ")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formatHeadingError(state.headingError))
                .font(GuidanceHUDStyles.mediumReadout)
                .foregroundColor(.secondary)
        }
    }

    private func formatHeadingError(_ error: Double) -> String {
        let degrees = error * 180 / .pi
        return String(format: "%.1f°", degrees)
    }

    // MARK: - Mode Indicators

    private var modeIndicators: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Control mode
                ModeBadge(
                    state.controlMode == .autoFollow ? "AUTO" : "MAN",
                    color: state.controlMode == .autoFollow ? GuidanceHUDColors.teal : .orange,
                    isActive: true
                )

                // Guidance state
                if state.abLine != nil {
                    ModeBadge(
                        "ON",
                        color: GuidanceHUDColors.green,
                        isActive: true
                    )
                } else {
                    ModeBadge(
                        "OFF",
                        color: .gray,
                        isActive: false
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var verticalDivider: some View {
        Divider()
            .frame(height: 28)
    }
}

// MARK: - Compact Status (Alternative)

/// Even more compact status for tight spaces
struct StatusCardCompact: View {
    @ObservedObject var state: AgGuidanceState

    var body: some View {
        HStack(spacing: 12) {
            // Lateral error
            Text(formatLateralError(state.crossTrackError))
                .font(GuidanceHUDStyles.largeReadout)
                .foregroundColor(GuidanceHUDColors.lateralErrorColor(state.crossTrackError))

            // Mode badge
            ModeBadge(
                state.controlMode == .autoFollow ? "A" : "M",
                color: state.controlMode == .autoFollow ? GuidanceHUDColors.teal : .orange,
                isActive: true
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .hudPanel()
    }

    private func formatLateralError(_ error: Double) -> String {
        let direction = error > 0 ? "→" : "←"
        return String(format: "%@ %.2fm", direction, abs(error))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            StatusCard(state: AgGuidanceState())
            StatusCardCompact(state: AgGuidanceState())
        }
        .padding()
    }
}
