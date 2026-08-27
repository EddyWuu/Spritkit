//
//  PixelationMethod.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-17.
//

import Foundation

// All available pixelation / stylization methods.
// Each case carries a user-facing name, SF Symbol, and short description.
nonisolated enum PixelationMethod: String, CaseIterable, Identifiable, Sendable {
    case standard
    case kuwaharaFilter
    case kMeansClustering
    case quantizeUpscale
    case edgeDetection
    case dither
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standard:         return "Standard"
        case .kuwaharaFilter:   return "Kuwahara"
        case .kMeansClustering: return "K-Means"
        case .quantizeUpscale:  return "Quantize + Upscale"
        case .edgeDetection:    return "Edge Detect"
        case .dither:           return "Dither"
        }
    }
    
    // Whether the method reduces the image to a limited palette (uses the Colors control).
    var usesPalette: Bool {
        switch self {
        case .standard, .kMeansClustering, .quantizeUpscale, .dither: return true
        case .kuwaharaFilter, .edgeDetection: return false
        }
    }
    
    var icon: String {
        switch self {
        case .standard:         return "square.grid.3x3.topleft.filled"
        case .kuwaharaFilter:   return "paintbrush.pointed"
        case .kMeansClustering: return "circle.hexagongrid"
        case .quantizeUpscale:  return "arrow.down.right.and.arrow.up.left"
        case .edgeDetection:    return "wand.and.rays"
        case .dither:           return "circle.dotted.and.circle"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .standard:
            return "Downscales, reduces to a cohesive palette, then upscales. Clean, true pixel art."
        case .kuwaharaFilter:
            return "Picks the smoothest neighborhood quadrant per pixel. Painterly, edge-preserving."
        case .kMeansClustering:
            return "Clusters colors with K-Means++ for vibrant, stable color regions."
        case .quantizeUpscale:
            return "Lanczos downscale, median-cut palette, nearest-neighbor upscale. Retro and crisp."
        case .edgeDetection:
            return "Sobel edge detection highlights outlines. Great for tracing or overlaying on pixel art."
        case .dither:
            return "Floyd-Steinberg error diffusion against a limited palette. Smooth retro gradients."
        }
    }
}
