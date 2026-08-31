//
//  Theme.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-08-31.
//

import SwiftUI

// MARK: - Palette

// Pixel-art palette pulled from the app icon: a red toolbox with grey tools.
enum Theme {
    
    // Toolbox reds
    static let accent      = Color(hex: "EB3F42")  // bright toolbox red
    static let accentBright = Color(hex: "FF4649")  // highlight red
    static let maroon      = Color(hex: "8C2536")  // deep toolbox body
    static let maroonDark  = Color(hex: "5C1420")  // shadowed red
    
    // Steel tools
    static let steel       = Color(hex: "7A848C")  // brushed tool grey
    static let steelLight  = Color(hex: "AEB6BD")  // tool highlight
    static let steelDark   = Color(hex: "4F4A4E")  // tool shadow
    
    // Ink / surfaces
    static let ink         = Color(hex: "140406")  // near-black red-tinted
    static let panel       = Color(hex: "1E1517")  // raised panel
    static let panelLight  = Color(hex: "2A1E21")  // lighter panel
    
    // Semantic
    static let onDark      = Color(hex: "EDE6E2")  // primary text on dark
    static let onDarkDim   = Color(hex: "9B9095")  // secondary text
    
    // Pixel geometry
    static let border: CGFloat = 2
    static let radius: CGFloat = 4        // tiny, keeps a blocky feel
    static let shadowOffset: CGFloat = 4  // hard offset (no blur) = retro
}

// MARK: - Pixel Font

extension Font {
    // Chunky monospaced font — evokes bitmap/pixel type without a custom font file.
    static func pixel(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Hard Pixel Shadow

extension View {
    // A solid, un-blurred offset shadow — the classic chunky "sticker" pixel-UI look.
    func pixelShadow(_ color: Color = Theme.ink, offset: CGFloat = Theme.shadowOffset) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(color)
                .offset(x: offset, y: offset)
        )
    }
}

// MARK: - Pixel Panel

// A blocky bordered surface with a hard drop shadow. Use to group controls.
struct PixelPanel<Content: View>: View {
    var fill: Color = Theme.panel
    var stroke: Color = Theme.steelDark
    var shadow: Bool = true
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(stroke, lineWidth: Theme.border)
            )
            .background(
                shadow
                ? RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.ink)
                    .offset(x: Theme.shadowOffset, y: Theme.shadowOffset)
                : nil
            )
    }
}

// MARK: - Pixel Button Style

// Blocky filled button that "presses" into its shadow when tapped.
struct PixelButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var textColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.pixel(15, weight: .heavy))
            .foregroundStyle(textColor)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(.black.opacity(0.35), lineWidth: Theme.border)
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.ink)
                    .offset(x: pressed ? 0 : Theme.shadowOffset,
                            y: pressed ? 0 : Theme.shadowOffset)
            )
            .offset(x: pressed ? Theme.shadowOffset : 0,
                    y: pressed ? Theme.shadowOffset : 0)
            .animation(.easeOut(duration: 0.06), value: pressed)
    }
}

// A quieter secondary style (steel tool look).
struct PixelSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.pixel(14, weight: .bold))
            .foregroundStyle(Theme.onDark)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.steelDark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.steel, lineWidth: Theme.border)
            )
            .opacity(pressed ? 0.7 : 1)
    }
}

// MARK: - Section Header

// A small blocky header label with a red tab accent.
struct PixelSectionHeader: View {
    let title: String
    var systemImage: String? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 8, height: 16)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.pixel(12))
            }
            Text(title.uppercased())
                .font(.pixel(12, weight: .heavy))
                .tracking(1)
            Spacer()
        }
        .foregroundStyle(Theme.onDark)
    }
}

// MARK: - Themed Empty State

// A blocky "no content" placeholder with an icon tile and an action.
struct PixelEmptyState<Action: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var action: () -> Action
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .strokeBorder(Theme.steelDark, lineWidth: Theme.border)
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.steel)
            }
            .pixelShadow()
            
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.pixel(16, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.onDark)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.pixel(12, weight: .medium))
                    .foregroundStyle(Theme.onDarkDim)
                    .multilineTextAlignment(.center)
            }
            
            action()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink)
    }
}

// MARK: - Themed Info Badge

// A small pixel-bordered badge for overlays (dimensions, status).
struct PixelBadge<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.panel.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .strokeBorder(Theme.steelDark, lineWidth: 1)
                    )
            )
    }
}
