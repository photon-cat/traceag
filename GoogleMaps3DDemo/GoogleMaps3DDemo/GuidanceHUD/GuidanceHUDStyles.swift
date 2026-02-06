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

/// Shared styling for Guidance HUD components
enum GuidanceHUDStyles {

    // MARK: - Materials

    /// Standard blur material for HUD elements
    static var blurMaterial: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
    }

    /// Darker blur for higher contrast
    static var darkBlurMaterial: some View {
        Rectangle()
            .fill(.regularMaterial)
    }

    // MARK: - Layout Constants

    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let padding: CGFloat = 12
    static let paddingCompact: CGFloat = 8
    static let spacing: CGFloat = 12
    static let spacingCompact: CGFloat = 8

    // MARK: - Typography

    static let largeReadout = Font.system(.title2, design: .monospaced).weight(.semibold)
    static let mediumReadout = Font.system(.subheadline, design: .monospaced).weight(.medium)
    static let smallReadout = Font.system(.caption, design: .monospaced)
    static let label = Font.system(.caption2, design: .default).weight(.medium)
    static let button = Font.system(.subheadline, design: .default).weight(.semibold)
    static let mode = Font.system(.caption, design: .default).weight(.bold)
}

// MARK: - View Modifiers

struct HUDPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = GuidanceHUDStyles.cornerRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct HUDCompactPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, GuidanceHUDStyles.paddingCompact)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: GuidanceHUDStyles.cornerRadiusSmall, style: .continuous))
    }
}

extension View {
    func hudPanel(cornerRadius: CGFloat = GuidanceHUDStyles.cornerRadius) -> some View {
        modifier(HUDPanelModifier(cornerRadius: cornerRadius))
    }

    func hudCompactPanel() -> some View {
        modifier(HUDCompactPanelModifier())
    }
}

// MARK: - Reusable Components

/// Small mode indicator badge
struct ModeBadge: View {
    let text: String
    let color: Color
    let isActive: Bool

    init(_ text: String, color: Color = .primary, isActive: Bool = true) {
        self.text = text
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        Text(text)
            .font(GuidanceHUDStyles.mode)
            .foregroundColor(isActive ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isActive ? color : color.opacity(0.2))
            )
    }
}

/// Segmented picker with consistent styling
struct HUDSegmentedPicker<T: Hashable>: View {
    let selection: Binding<T>
    let options: [(T, String)]
    var width: CGFloat = 90

    var body: some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: width)
    }
}

/// Icon-based segmented picker
struct HUDIconPicker<T: Hashable>: View {
    let selection: Binding<T>
    let options: [(T, String)]  // (value, SF Symbol name)
    var width: CGFloat = 80

    var body: some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.0) { option in
                Image(systemName: option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: width)
    }
}

/// Action button with consistent HUD styling
struct HUDActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(GuidanceHUDStyles.button)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}

/// Compact icon-only button
struct HUDIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ModeBadge("AUTO", color: GuidanceHUDColors.teal, isActive: true)
        ModeBadge("MANUAL", color: .gray, isActive: false)

        HStack {
            HUDActionButton(title: "Set A", icon: "mappin", color: .green) {}
            HUDActionButton(title: "Clear", icon: "xmark.circle", color: .red) {}
        }
    }
    .padding()
    .background(Color.black)
}
