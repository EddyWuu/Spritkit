//
//  ExportPayload.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import UIKit

// Supported export formats
enum ExportFormat: String, Codable, CaseIterable, Identifiable {
    case png            // Single image
    case spriteSheet    // Sheet PNG + JSON metadata
    case palette        // Palette JSON (.spritepalette)
    case gif            // Animated GIF
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .spriteSheet: return "json"
        case .palette: return "spritepalette"
        case .gif: return "gif"
        }
    }
    
    var label: String {
        switch self {
        case .png: return "PNG Image"
        case .spriteSheet: return "Sprite Sheet + JSON"
        case .palette: return "Palette File"
        case .gif: return "Animated GIF"
        }
    }
}

// Wraps data to be exported or shared
struct ExportPayload {
    var format: ExportFormat
    var name: String
    var images: [CGImage]
    var metadata: ExportMetadata?
    var palette: Palette?
    
    // Generate shareable items for UIActivityViewController
    func shareItems() -> [Any] {
        var items: [Any] = []
        
        switch format {
        case .png:
            for image in images {
                items.append(UIImage(cgImage: image))
            }
            
        case .spriteSheet:
            if let first = images.first {
                items.append(UIImage(cgImage: first))
            }
            if let metadata = metadata,
               let jsonData = try? JSONEncoder().encode(metadata) {
                items.append(jsonData)
            }
            
        case .palette:
            if let palette = palette,
               let jsonData = try? JSONEncoder().encode(palette) {
                items.append(jsonData)
            }
            
        case .gif:
            // GIF export handled separately via ImageIO
            for image in images {
                items.append(UIImage(cgImage: image))
            }
        }
        
        return items
    }
}

// JSON metadata for sprite sheet exports (TexturePacker-compatible format)
struct ExportMetadata: Codable {
    var appName: String = "Spritkit"
    var version: String = "1.0"
    var imageName: String
    var imageWidth: Int
    var imageHeight: Int
    var frames: [ExportFrameInfo]
}

// Per-frame info in sprite sheet metadata
struct ExportFrameInfo: Codable {
    var filename: String
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var index: Int
}
