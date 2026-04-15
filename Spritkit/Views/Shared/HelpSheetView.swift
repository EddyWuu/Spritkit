//
//  HelpSheetView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-15.
//

import SwiftUI

struct HelpItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct HelpSheetView: View {
    
    let title: String
    let subtitle: String
    let items: [HelpItem]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    // Steps / info
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Help content for each tab

extension HelpSheetView {
    
    static var pixelate: HelpSheetView {
        HelpSheetView(
            title: "Pixelate",
            subtitle: "Turn any photo into pixel art by applying a mosaic block effect.",
            items: [
                HelpItem(icon: "photo.badge.plus", title: "Import a Photo", description: "Tap the import button in the toolbar to pick a photo from your library or camera."),
                HelpItem(icon: "slider.horizontal.3", title: "Adjust Block Size", description: "Use the slider to control how large each pixel block is. Higher values = chunkier pixels, lower values = more detail."),
                HelpItem(icon: "wand.and.stars", title: "Apply", description: "Tap the Pixelate button to process. The output preview updates in the canvas above."),
                HelpItem(icon: "square.and.arrow.up", title: "Export", description: "Use the share button to save or share the pixelated result."),
                HelpItem(icon: "xmark.circle", title: "Start Over", description: "Tap the red ✕ in the toolbar to clear everything and start fresh with a new image.")
            ]
        )
    }
    
    static var scaleSprite: HelpSheetView {
        HelpSheetView(
            title: "Scale Sprite",
            subtitle: "Resize sprites using nearest-neighbor interpolation to keep pixel edges crisp — no blurry anti-aliasing.",
            items: [
                HelpItem(icon: "photo.badge.plus", title: "Import a Sprite", description: "Tap the import button to pick a sprite image from your library."),
                HelpItem(icon: "arrow.up.left.and.arrow.down.right", title: "Choose Scale Mode", description: "Use the factor slider (2×, 4×, 8×, etc.) for quick scaling, or toggle Custom Dimensions to set exact width and height."),
                HelpItem(icon: "lock", title: "Lock Aspect Ratio", description: "When using custom dimensions, the lock icon keeps width and height proportional so your sprite doesn't stretch."),
                HelpItem(icon: "wand.and.stars", title: "Scale", description: "Tap the Scale button. The dimension badge shows input and output sizes."),
                HelpItem(icon: "square.and.arrow.up", title: "Export", description: "Save or share the scaled result with the share button.")
            ]
        )
    }
    
    static var extractPalette: HelpSheetView {
        HelpSheetView(
            title: "Extract Palette",
            subtitle: "Analyze any image and pull out its dominant colors as a palette. Duplicate colors are automatically merged.",
            items: [
                HelpItem(icon: "photo.badge.plus", title: "Import an Image", description: "Tap the import button to pick any image — photos, sprites, or pixel art all work."),
                HelpItem(icon: "number", title: "Set Max Colors", description: "Choose how many colors to extract (4, 8, 16, 32, etc.). If the image has fewer unique colors, only the actual colors are shown — no duplicates."),
                HelpItem(icon: "paintpalette", title: "Extract", description: "Tap Extract Palette. Colors appear in a grid sorted by frequency."),
                HelpItem(icon: "hand.tap", title: "Copy a Color", description: "Tap any color swatch to select it and automatically copy its hex code to your clipboard."),
                HelpItem(icon: "doc.on.clipboard", title: "Use in Spritfill", description: "Copied hex values can be pasted directly into Spritfill's custom palette input.")
            ]
        )
    }
    
    static var spriteSheetCutter: HelpSheetView {
        HelpSheetView(
            title: "Sprite Sheet Cutter",
            subtitle: "Slice a sprite sheet into individual frames, then organize them into named animation clips.",
            items: [
                HelpItem(icon: "photo.badge.plus", title: "Import a Sprite Sheet", description: "Load a sprite sheet — a single image containing multiple sprites arranged in a grid or packed layout."),
                HelpItem(icon: "rectangle.split.3x3", title: "Set Grid or Auto-Detect", description: "Grid mode: set rows, columns, and padding to match your sheet's layout. Auto-detect finds non-transparent regions automatically."),
                HelpItem(icon: "scissors", title: "Slice", description: "Tap Slice Sheet to cut the image into individual frames. They appear in the frame strip below."),
                HelpItem(icon: "hand.tap", title: "Select Frames", description: "Tap frames to select them. Use Select All / Deselect All for quick selection. Selected frames get a blue checkmark."),
                HelpItem(icon: "tag.fill", title: "Create Animation Clips", description: "With frames selected, tap Create Clip to name them (e.g. 'Walk', 'Attack') and assign a color tag. A sheet can have multiple different animations — each clip groups related frames."),
                HelpItem(icon: "play.fill", title: "Preview", description: "Tap Preview on a clip card to jump to the Animate tab and see that animation play. Or use 'All → Animate' to send every frame."),
                HelpItem(icon: "square.and.arrow.down", title: "Save Frames", description: "Long-press any frame to save or share it individually. Use the download icon to save all frames at once.")
            ]
        )
    }
    
    static var animationPreview: HelpSheetView {
        HelpSheetView(
            title: "Animation Preview",
            subtitle: "Play back sprite animation frames with adjustable speed and playback modes. Frames come from the Sheet Cutter.",
            items: [
                HelpItem(icon: "rectangle.split.3x3", title: "Get Frames", description: "Use the Sheet Cutter tab first to slice a sprite sheet and send frames here via the Preview or 'All → Animate' buttons."),
                HelpItem(icon: "tag.fill", title: "Switch Clips", description: "If you created named animation clips (Walk, Attack, Idle), use the colored chips at the top to switch between them. 'All Frames' shows everything."),
                HelpItem(icon: "play.fill", title: "Playback Controls", description: "Play, pause, stop, and step frame-by-frame. Tap any frame in the timeline strip to jump directly to it."),
                HelpItem(icon: "speedometer", title: "Adjust FPS", description: "Use the speed slider to set frames per second (1–60 FPS). Most pixel art animations look good at 8–12 FPS."),
                HelpItem(icon: "repeat", title: "Playback Modes", description: "Loop: repeats from start. Ping-Pong: plays forward then backward. One-Shot: plays once and stops.")
            ]
        )
    }
}
