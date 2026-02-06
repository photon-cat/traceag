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

/// Primary action row with main guidance controls
struct BottomActionRow: View {
    @ObservedObject var state: AgGuidanceState
    @Binding var showSettings: Bool
    @Binding var showSimulatorDrawer: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Set AB / New Line button
            abButton

            // Start/Stop Coverage toggle
            coverageButton

            // Reset / Clear button
            clearButton

            // Simulator toggle (only in sim mode)
            if state.positionSourceType == .simulator {
                simButton
            }

            Spacer()

            // Settings button
            settingsButton
        }
        .padding(.horizontal, GuidanceHUDStyles.padding)
        .padding(.vertical, 8)
    }

    // MARK: - AB Line Button

    private var abButton: some View {
        Button(action: { state.setABPoint() }) {
            Label(state.abPointState.rawValue, systemImage: abButtonIcon)
                .font(GuidanceHUDStyles.button)
        }
        .buttonStyle(.borderedProminent)
        .tint(abButtonColor)
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

    // MARK: - Coverage Button

    private var coverageButton: some View {
        Button(action: { state.implementActive.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: state.implementActive ? "paintbrush.fill" : "paintbrush")
                Text(state.implementActive ? "ON" : "OFF")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(state.implementActive ? GuidanceHUDColors.green : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Clear Button

    private var clearButton: some View {
        Button(action: { state.clearCoverage() }) {
            Label("Clear", systemImage: "xmark.circle")
                .font(GuidanceHUDStyles.button)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    // MARK: - Simulator Button

    private var simButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSimulatorDrawer.toggle()
            }
        }) {
            Image(systemName: showSimulatorDrawer ? "gamecontroller.fill" : "gamecontroller")
                .font(.title3)
        }
        .buttonStyle(.borderedProminent)
        .tint(GuidanceHUDColors.simulator)
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            BottomActionRow(
                state: AgGuidanceState(),
                showSettings: .constant(false),
                showSimulatorDrawer: .constant(false)
            )
        }
    }
}
