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

struct DemoCatalogView: View {
    private let sections: [DemoSection] = [
        DemoSection(
            title: "Maps Essentials",
            subtitle: "Explore base rendering and camera control.",
            items: [
                DemoItem(title: "Basic Map", subtitle: "Hybrid view with minimal setup.", systemImage: "map", destination: AnyView(ContentView())),
                DemoItem(title: "Camera Demo", subtitle: "Move, tilt, and orbit the camera.", systemImage: "camera.viewfinder", destination: AnyView(CameraDemo())),
                DemoItem(title: "Camera Restrictions", subtitle: "Constrain tilt and zoom.", systemImage: "viewfinder", destination: AnyView(CameraRestrictionDemo()))
            ]
        ),
        DemoSection(
            title: "Places & Markers",
            subtitle: "Interact with points of interest.",
            items: [
                DemoItem(title: "Marker Demo", subtitle: "Custom markers and info.", systemImage: "mappin.and.ellipse", destination: AnyView(MarkerDemo())),
                DemoItem(title: "Marker Collision", subtitle: "Smart marker layout.", systemImage: "square.stack.3d.down.right", destination: AnyView(MarkerCollisionDemo())),
                DemoItem(title: "Place Tap Demo", subtitle: "Tap on places and see details.", systemImage: "hand.tap", destination: AnyView(PlaceTapDemo()))
            ]
        ),
        DemoSection(
            title: "3D Storytelling",
            subtitle: "Models, shapes, and flight paths.",
            items: [
                DemoItem(title: "3D Models", subtitle: "Place and animate assets.", systemImage: "cube.transparent", destination: AnyView(ModelDemo())),
                DemoItem(title: "Shapes Demo", subtitle: "Draw polygons and paths.", systemImage: "square.on.circle", destination: AnyView(ShapesDemo())),
                DemoItem(title: "Flight Path Demo", subtitle: "Follow a pre-defined route.", systemImage: "paperplane", destination: AnyView(FlyAlongRouteDemo()))
            ]
        ),
        DemoSection(
            title: "Guidance",
            subtitle: "Precision workflow with guidance overlays.",
            items: [
                DemoItem(title: "Ag Guidance Demo", subtitle: "Full guidance experience.", systemImage: "location.north.line", destination: AnyView(AgGuidanceDemo()))
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FieldBeeSectionHeader("Sample Library", subtitle: "Organized demos with a FieldBee-styled layout.")
                    .padding(.top, 8)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        FieldBeeSectionHeader(section.title, subtitle: section.subtitle)
                        ForEach(section.items) { item in
                            NavigationLink {
                                item.destination
                            } label: {
                                FieldBeeCard {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.systemImage)
                                            .font(.title2)
                                            .foregroundColor(FieldBeeColor.leaf)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.headline)
                                                .foregroundColor(FieldBeeColor.ink)
                                            Text(item.subtitle)
                                                .font(.caption)
                                                .foregroundColor(FieldBeeColor.slate)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(FieldBeeColor.slate)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(FieldBeeColor.mist.ignoresSafeArea())
        .navigationTitle("Samples")
    }
}

struct DemoSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let items: [DemoItem]
}

struct DemoItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let destination: AnyView
}

#Preview {
    NavigationStack {
        DemoCatalogView()
    }
}
