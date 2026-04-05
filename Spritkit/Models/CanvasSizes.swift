//
//  CanvasSizes.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//
//  Matches Spritfill's CanvasSizes enum for cross-app compatibility.
//

import Foundation

// MARK: - Canvas Sizes (matches Spritfill)

enum CanvasSizes: String, CaseIterable, Codable {
    
    case smallSquare        // 16x16
    case mediumSquare       // 32x32
    case midSquare          // 48x48
    case largeSquare        // 64x64
    case extraLargeSquare   // 128x128
    case hugeSquare         // 256x256
    case massiveSquare      // 512x512
    case wide               // 64x32
    case tall               // 32x64
    case landscape          // 80x60
    case portrait           // 60x80
    case wideCinematic      // 96x128
    case landscapeBanner    // 128x96
    
    // (width, height)
    var dimensions: (width: Int, height: Int) {
        switch self {
        case .smallSquare:      return (16, 16)
        case .mediumSquare:     return (32, 32)
        case .midSquare:        return (48, 48)
        case .largeSquare:      return (64, 64)
        case .extraLargeSquare: return (128, 128)
        case .hugeSquare:       return (256, 256)
        case .massiveSquare:    return (512, 512)
        case .wide:             return (64, 32)
        case .tall:             return (32, 64)
        case .landscape:        return (80, 60)
        case .portrait:         return (60, 80)
        case .wideCinematic:    return (96, 128)
        case .landscapeBanner:  return (128, 96)
        }
    }
    
    // Find a matching CanvasSizes case from width and height, or nil if no match
    static func from(width: Int, height: Int) -> CanvasSizes? {
        return CanvasSizes.allCases.first { $0.dimensions.width == width && $0.dimensions.height == height }
    }
    
    var displayName: String {
        let d = dimensions
        return "\(d.width)×\(d.height)"
    }
}
