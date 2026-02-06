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

/// Collapsible drawer for simulator controls
struct SimulatorDrawer: View {
    @ObservedObject var state: AgGuidanceState
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header / drag handle
            drawerHeader

            // Expandable content
            if isExpanded {
                drawerContent
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: GuidanceHUDStyles.cornerRadius, style: .continuous))
    }

    // MARK: - Header

    private var drawerHeader: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundColor(GuidanceHUDColors.simulator)
                Text("Simulator")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, GuidanceHUDStyles.padding)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }

    // MARK: - Content

    private var drawerContent: some View {
        VStack(spacing: GuidanceHUDStyles.spacing) {
            Divider()

            // Speed controls
            speedControls

            Divider()

            // Turn controls
            turnControls

            // Heading display
            headingDisplay
        }
        .padding(.horizontal, GuidanceHUDStyles.padding)
        .padding(.bottom, GuidanceHUDStyles.padding)
    }

    // MARK: - Speed Controls

    private var speedControls: some View {
        HStack {
            Text("Speed")
                .font(.caption.bold())
                .frame(width: 50, alignment: .leading)

            Button(action: { state.decreaseSimulatorSpeed() }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }

            Text(String(format: "%.1f m/s", state.simulatorSpeed))
                .font(GuidanceHUDStyles.mediumReadout)
                .frame(minWidth: 70)

            Button(action: { state.increaseSimulatorSpeed() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }

            Spacer()
        }
    }

    // MARK: - Turn Controls

    private var turnControls: some View {
        HStack(spacing: 20) {
            Text("Turn")
                .font(.caption.bold())
                .frame(width: 50, alignment: .leading)

            // Left turn button
            turnButton(direction: -1.0, icon: "arrow.turn.up.left")

            Spacer()

            // Right turn button
            turnButton(direction: 1.0, icon: "arrow.turn.up.right")

            Spacer()
        }
    }

    private func turnButton(direction: Double, icon: String) -> some View {
        Image(systemName: icon)
            .font(.title2.bold())
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(Circle().fill(Color.blue))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if direction < 0 {
                            state.simulatorTurnLeft()
                        } else {
                            state.simulatorTurnRight()
                        }
                    }
                    .onEnded { _ in
                        state.simulatorReleaseTurn()
                    }
            )
    }

    // MARK: - Heading Display

    private var headingDisplay: some View {
        HStack {
            Text("Heading")
                .font(.caption.bold())
                .frame(width: 50, alignment: .leading)
            Text(String(format: "%.1f°", state.vehicleHeading * 180 / .pi))
                .font(GuidanceHUDStyles.smallReadout)
            Spacer()
        }
    }
}

// MARK: - Steering Controls (For Manual Mode)

struct SteeringControls: View {
    @ObservedObject var state: AgGuidanceState

    var body: some View {
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
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            SimulatorDrawer(
                state: AgGuidanceState(),
                isExpanded: .constant(true)
            )
            .padding()
        }
    }
}
