//
//  SpriteModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import UIKit

// Represents a single sprite — either imported or produced by an operation.
// Supports Spritfill's [String] pixel grid format for cross-app interop.
struct Sprite: Identifiable, Codable {
    
    let id: UUID
    var name: String
    var width: Int
    var height: Int
    var sourceApp: SourceApp
    var createdAt: Date
    var tags: [String]
    
    // Pixel data as flat hex string array (matches Spritfill's ProjectData.pixelGrid).
    // "clear" = transparent pixel, "#RRGGBB" = colored pixel.
    // Length = width * height.
    var pixelGrid: [String]?
    
    // Which app created this sprite
    enum SourceApp: String, Codable {
        case spritkit
        case spritfill
        case imported
    }
    
    // File name for the PNG on disk (inside shared container or app sandbox)
    var pngFilename: String {
        "\(id.uuidString).png"
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        width: Int,
        height: Int,
        sourceApp: SourceApp = .spritkit,
        createdAt: Date = Date(),
        tags: [String] = [],
        pixelGrid: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.tags = tags
        self.pixelGrid = pixelGrid
    }
}

extension Sprite {
    
    // Create a Sprite model from a CGImage
    static func from(_ cgImage: CGImage, name: String, sourceApp: SourceApp = .spritkit) -> Sprite {
        Sprite(
            name: name,
            width: cgImage.width,
            height: cgImage.height,
            sourceApp: sourceApp
        )
    }
    
    // Create a Sprite model from a Spritfill ProjectData-style pixel grid
    static func fromPixelGrid(_ grid: [String], width: Int, height: Int, name: String) -> Sprite {
        Sprite(
            name: name,
            width: width,
            height: height,
            sourceApp: .spritfill,
            pixelGrid: grid
        )
    }
    
    // Convert a CGImage to a pixel grid [String] (hex or "clear")
    static func pixelGridFrom(_ cgImage: CGImage) -> [String]? {
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var grid: [String] = []
        grid.reserveCapacity(width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]
                let a: UInt8 = bytesPerPixel >= 4 ? ptr[offset + 3] : 255
                
                if a < 10 {
                    grid.append("clear")
                } else {
                    grid.append(String(format: "#%02X%02X%02X", r, g, b))
                }
            }
        }
        
        return grid
    }
}
