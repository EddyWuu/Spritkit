//
//  PaletteModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import SwiftUI

// MARK: - Palette Color (view-level convenience with frequency data from extraction)

nonisolated struct PaletteColor: Identifiable, Codable, Hashable, Sendable {
    
    let id: UUID
    
    // Hex string (e.g. "#FF5733") — primary storage format, matches Spritfill
    let hex: String
    
    // Pixel count — how many pixels in the source image matched this color bucket
    var frequency: Int
    
    init(id: UUID = UUID(), hex: String, frequency: Int = 0) {
        self.id = id
        self.hex = hex
        self.frequency = frequency
    }
    
    // Convenience init from RGB doubles (used by ImageProcessingService)
    init(id: UUID = UUID(), red: Double, green: Double, blue: Double, frequency: Int = 0) {
        self.id = id
        self.hex = String(format: "#%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
        self.frequency = frequency
    }
    
    // SwiftUI Color
    @MainActor var color: Color {
        Color(hex: hex)
    }
    
    // UIColor
    @MainActor var uiColor: UIColor {
        UIColor(hex: hex.replacingOccurrences(of: "#", with: ""))
    }
}

// MARK: - Palette (collection of colors)

nonisolated struct Palette: Identifiable, Codable, Sendable {
    
    let id: UUID
    var name: String
    var colors: [PaletteColor]
    var createdAt: Date
    
    // Source sprite this palette was extracted from, if any
    var sourceSpriteId: UUID?
    
    init(
        id: UUID = UUID(),
        name: String = "Untitled Palette",
        colors: [PaletteColor] = [],
        createdAt: Date = Date(),
        sourceSpriteId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.colors = colors
        self.createdAt = createdAt
        self.sourceSpriteId = sourceSpriteId
    }
    
    // Number of unique colors
    var colorCount: Int { colors.count }
    
    // Hex string array — matches Spritfill's CustomPaletteData.hexColors format
    var hexColors: [String] {
        colors.map { $0.hex }
    }
    
    // Create a Palette from a simple hex array (Spritfill import)
    static func from(hexColors: [String], name: String = "Imported Palette") -> Palette {
        let paletteColors = hexColors.map { PaletteColor(hex: $0) }
        return Palette(name: name, colors: paletteColors)
    }
}
