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

/// Single compact top HUD strip with view controls
struct TopHUDStrip: View {
    @ObservedObject var state: AgGuidanceState

    var body: some View {
        HStack(spacing: GuidanceHUDStyles.spacing) {
            // Left: View mode (2D | 3D)
            viewModeSegment

            Spacer()

            // Center: Orientation (Heading-Up | North-Up)
            orientationSegment

            Spacer()

            // Right: Base layer (Grid | Satellite)
            baseLayerSegment
        }
        .padding(.horizontal, GuidanceHUDStyles.padding)
        .padding(.vertical, 10)
        .hudPanel()
    }

    // MARK: - View Mode

    private var viewModeSegment: some View {
        Picker("View", selection: $state.viewMode) {
            Text("2D").tag(ViewMode.topDown2D)
            Text("3D").tag(ViewMode.perspective3D)
        }
        .pickerStyle(.segmented)
        .frame(width: 80)
        .onChange(of: state.viewMode) { _, newValue in
            state.updateViewMode(newValue)
        }
    }

    // MARK: - Orientation

    private var orientationSegment: some View {
        Picker("Orientation", selection: $state.headingMode) {
            Image(systemName: "location.north").tag(HeadingMode.northUp)
            Image(systemName: "location.north.line.fill").tag(HeadingMode.headingUp)
        }
        .pickerStyle(.segmented)
        .frame(width: 90)
    }

    // MARK: - Base Layer

    private var baseLayerSegment: some View {
        Picker("Layer", selection: $state.backgroundMode) {
            Text("Grid").tag(BackgroundMode.checkerboard)
            Text("Sat").tag(BackgroundMode.satellite)
        }
        .pickerStyle(.segmented)
        .frame(width: 90)
        .onChange(of: state.backgroundMode) { _, newValue in
            state.updateBackgroundMode(newValue)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            TopHUDStrip(state: AgGuidanceState())
                .padding()
            Spacer()
        }
    }
}
