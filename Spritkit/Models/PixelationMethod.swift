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
    case bilateralGrid
    case voronoi
    case superpixelSLIC
    case edgeDetection
    case dither
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standard:         return "Standard"
        case .kuwaharaFilter:   return "Kuwahara"
        case .kMeansClustering: return "K-Means"
        case .quantizeUpscale:  return "Quantize + Upscale"
        case .bilateralGrid:    return "Bilateral + Grid"
        case .voronoi:          return "Voronoi"
        case .superpixelSLIC:   return "Superpixel (SLIC)"
        case .edgeDetection:    return "Edge Detect"
        case .dither:           return "Ordered Dither"
        }
    }
    
    var icon: String {
        switch self {
        case .standard:         return "square.grid.3x3.topleft.filled"
        case .kuwaharaFilter:   return "paintbrush.pointed"
        case .kMeansClustering: return "circle.hexagongrid"
        case .quantizeUpscale:  return "arrow.down.right.and.arrow.up.left"
        case .bilateralGrid:    return "slider.horizontal.below.square.and.square.filled"
        case .voronoi:          return "diamond.inset.filled"
        case .superpixelSLIC:   return "hexagon"
        case .edgeDetection:    return "wand.and.rays"
        case .dither:           return "circle.dotted.and.circle"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .standard:
            return "Classic block averaging via CIPixellate. Fast and clean."
        case .kuwaharaFilter:
            return "Picks the smoothest neighborhood quadrant per pixel. Painterly, edge-preserving."
        case .kMeansClustering:
            return "Clusters colors via K-Means, then assigns each block to its nearest centroid. Sharp color regions."
        case .quantizeUpscale:
            return "Downscale with Lanczos, quantize colors, then upscale with nearest-neighbor. Retro and crisp."
        case .bilateralGrid:
            return "Bilateral filter smooths flat areas while preserving edges, then grid-averages. Clean blocks."
        case .voronoi:
            return "Colors each pixel by its nearest grid seed point. Organic, slightly irregular blocks."
        case .superpixelSLIC:
            return "Groups pixels into irregular perceptual blobs. Cells follow image content and edges."
        case .edgeDetection:
            return "Sobel edge detection highlights outlines. Great for tracing or overlaying on pixel art."
        case .dither:
            return "Ordered Bayer dithering with reduced palette. Classic retro / Game Boy aesthetic."
        }
    }
}
