//
//  ImageProcessingService.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import CoreImage
import UIKit

// Stateless image processing service.
// All methods are async and run heavy work off the main thread.
// Explicitly nonisolated — processing should never block the main actor.
nonisolated enum ImageProcessingService {
    
    // MARK: - Shared CIContext (reuse for performance)
    
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - Pixelate
    
    // Pixelate an image using CIPixellate filter.
    // - Parameters:
    //   - image: Source CGImage
    //   - blockSize: Pixel block size (higher = more pixelated). Clamped to 1...256.
    // - Returns: Pixelated CGImage
    static func pixelate(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        let clamped = min(max(blockSize, 1), 256)
        
        return try await Task.detached {
            let ciImage = CIImage(cgImage: image)
            
            guard let filter = CIFilter(name: "CIPixellate") else {
                throw ProcessingError.filterUnavailable("CIPixellate")
            }
            
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(clamped, forKey: kCIInputScaleKey)
            filter.setValue(CIVector(x: 0, y: 0), forKey: kCIInputCenterKey)
            
            guard let output = filter.outputImage else {
                throw ProcessingError.filterFailed("CIPixellate produced no output")
            }
            
            // Crop to original bounds (CIPixellate can extend edges)
            let cropped = output.cropped(to: ciImage.extent)
            
            guard let cgResult = ciContext.createCGImage(cropped, from: cropped.extent) else {
                throw ProcessingError.renderFailed
            }
            
            return cgResult
        }.value
    }
    
    // MARK: - Scale (Nearest Neighbor)
    
    // Scale an image using nearest-neighbor interpolation (preserves pixel-art crispness).
    // - Parameters:
    //   - image: Source CGImage
    //   - factor: Scale factor (e.g., 2.0 = double size, 0.5 = half size). Clamped to 0.1...32.
    // - Returns: Scaled CGImage
    static func scaleNearestNeighbor(image: CGImage, factor: CGFloat) async throws -> CGImage {
        let clamped = min(max(factor, 0.1), 32)
        let newWidth = Int(CGFloat(image.width) * clamped)
        let newHeight = Int(CGFloat(image.height) * clamped)
        
        guard newWidth > 0, newHeight > 0 else {
            throw ProcessingError.invalidParameters("Resulting dimensions are zero")
        }
        
        return try await Task.detached {
            guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
                throw ProcessingError.renderFailed
            }
            
            guard let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ProcessingError.renderFailed
            }
            
            // Nearest-neighbor — no interpolation
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            
            guard let result = context.makeImage() else {
                throw ProcessingError.renderFailed
            }
            
            return result
        }.value
    }
    
    // MARK: - Extract Palette (Median Cut)
    
    // Extract dominant colors from an image using a simplified median-cut algorithm.
    // - Parameters:
    //   - image: Source CGImage
    //   - maxColors: Maximum number of colors to extract (default 16)
    // - Returns: Palette with extracted colors sorted by frequency
    static func extractPalette(image: CGImage, maxColors: Int = 16) async throws -> Palette {
        return try await Task.detached {
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let width = image.width
            let height = image.height
            let bytesPerPixel = image.bitsPerPixel / 8
            let bytesPerRow = image.bytesPerRow
            
            // Collect all pixel colors
            var pixels: [(r: UInt8, g: UInt8, b: UInt8)] = []
            pixels.reserveCapacity(width * height)
            
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    let r = ptr[offset]
                    let g = ptr[offset + 1]
                    let b = ptr[offset + 2]
                    // Skip fully transparent pixels
                    if bytesPerPixel >= 4 {
                        let a = ptr[offset + 3]
                        if a == 0 { continue }
                    }
                    pixels.append((r, g, b))
                }
            }
            
            guard !pixels.isEmpty else {
                return Palette(name: "Empty", colors: [])
            }
            
            // Simplified median-cut: recursively split the color space
            let buckets = medianCut(pixels: pixels, depth: depthForCount(maxColors))
            
            // Convert buckets to PaletteColors (hex-primary, matches Spritfill)
            var colors: [PaletteColor] = buckets.map { bucket in
                let avg = averageColor(bucket)
                return PaletteColor(
                    red: Double(avg.r) / 255.0,
                    green: Double(avg.g) / 255.0,
                    blue: Double(avg.b) / 255.0,
                    frequency: bucket.count
                )
            }
            
            // Deduplicate: merge buckets that averaged to the same hex color.
            // This prevents showing 128 copies of the same color when the image
            // only has 3 actual colors.
            var seen: [String: Int] = [:] // hex -> index in deduped array
            var deduped: [PaletteColor] = []
            for color in colors {
                if let existingIdx = seen[color.hex] {
                    // Merge frequency into the existing entry
                    deduped[existingIdx] = PaletteColor(
                        hex: color.hex,
                        frequency: deduped[existingIdx].frequency + color.frequency
                    )
                } else {
                    seen[color.hex] = deduped.count
                    deduped.append(color)
                }
            }
            colors = deduped
            
            // Sort by frequency (most common first)
            colors.sort { $0.frequency > $1.frequency }
            
            // Limit to maxColors
            if colors.count > maxColors {
                colors = Array(colors.prefix(maxColors))
            }
            
            return Palette(name: "Extracted Palette", colors: colors)
        }.value
    }
    
    // MARK: - Sprite Sheet Slicing
    
    // Slice a sprite sheet into individual frames.
    // - Parameters:
    //   - image: Source sprite sheet CGImage
    //   - sheet: SpriteSheet model with frame definitions (call computeGridFrames() first for grid mode)
    // - Returns: Array of (AnimationFrame, CGImage) tuples
    static func sliceSheet(image: CGImage, sheet: SpriteSheet) async throws -> [(AnimationFrame, CGImage)] {
        guard !sheet.frames.isEmpty else {
            throw ProcessingError.invalidParameters("No frames defined in sprite sheet")
        }
        
        return try await Task.detached {
            var results: [(AnimationFrame, CGImage)] = []
            
            for frameRect in sheet.frames {
                let rect = frameRect.cgRect
                
                guard let cropped = image.cropping(to: rect) else {
                    throw ProcessingError.sliceFailed(index: frameRect.index)
                }
                
                let frame = AnimationFrame(
                    index: frameRect.index,
                    width: cropped.width,
                    height: cropped.height
                )
                
                results.append((frame, cropped))
            }
            
            return results.sorted { $0.0.index < $1.0.index }
        }.value
    }
    
    // MARK: - Auto-Detect Frames
    
    // Detect individual sprite bounding boxes in a sprite sheet by finding
    // connected non-transparent regions.
    // - Parameter image: Source sprite sheet CGImage with transparent background
    // - Returns: Array of FrameRects for detected sprites
    static func autoDetectFrames(image: CGImage) async throws -> [FrameRect] {
        return try await Task.detached {
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let width = image.width
            let height = image.height
            let bytesPerPixel = image.bitsPerPixel / 8
            let bytesPerRow = image.bytesPerRow
            
            guard bytesPerPixel >= 4 else {
                throw ProcessingError.invalidParameters("Image must have an alpha channel for auto-detection")
            }
            
            // Build a binary mask: true = non-transparent pixel
            var visited = Array(repeating: false, count: width * height)
            var frames: [FrameRect] = []
            
            func isOpaque(x: Int, y: Int) -> Bool {
                let offset = y * bytesPerRow + x * bytesPerPixel
                return ptr[offset + 3] > 10 // Alpha threshold
            }
            
            // Flood-fill to find connected regions
            for y in 0..<height {
                for x in 0..<width {
                    let idx = y * width + x
                    if visited[idx] || !isOpaque(x: x, y: y) { continue }
                    
                    // BFS to find bounding box of this connected region
                    var minX = x, maxX = x, minY = y, maxY = y
                    var queue = [(x, y)]
                    visited[idx] = true
                    
                    while !queue.isEmpty {
                        let (cx, cy) = queue.removeFirst()
                        minX = min(minX, cx)
                        maxX = max(maxX, cx)
                        minY = min(minY, cy)
                        maxY = max(maxY, cy)
                        
                        // Check 4-connected neighbors
                        for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)] {
                            let nx = cx + dx
                            let ny = cy + dy
                            guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                            let nIdx = ny * width + nx
                            guard !visited[nIdx], isOpaque(x: nx, y: ny) else { continue }
                            visited[nIdx] = true
                            queue.append((nx, ny))
                        }
                    }
                    
                    // Only add if the region is big enough (ignore stray pixels)
                    let regionWidth = maxX - minX + 1
                    let regionHeight = maxY - minY + 1
                    if regionWidth >= 4 && regionHeight >= 4 {
                        frames.append(FrameRect(
                            x: minX, y: minY,
                            width: regionWidth, height: regionHeight,
                            index: frames.count
                        ))
                    }
                }
            }
            
            // Sort left-to-right, top-to-bottom
            return frames.sorted { a, b in
                if a.y != b.y { return a.y < b.y }
                return a.x < b.x
            }
        }.value
    }
    
    // MARK: - Errors
    
    enum ProcessingError: LocalizedError {
        case filterUnavailable(String)
        case filterFailed(String)
        case renderFailed
        case pixelAccessFailed
        case invalidParameters(String)
        case sliceFailed(index: Int)
        
        var errorDescription: String? {
            switch self {
            case .filterUnavailable(let name): return "CIFilter '\(name)' is not available"
            case .filterFailed(let msg): return "Filter failed: \(msg)"
            case .renderFailed: return "Failed to render image"
            case .pixelAccessFailed: return "Failed to access pixel data"
            case .invalidParameters(let msg): return "Invalid parameters: \(msg)"
            case .sliceFailed(let index): return "Failed to slice frame at index \(index)"
            }
        }
    }
}

// MARK: - Median Cut Helpers (Private)

extension ImageProcessingService {
    
    fileprivate typealias Pixel = (r: UInt8, g: UInt8, b: UInt8)
    
    fileprivate nonisolated static func depthForCount(_ count: Int) -> Int {
        var depth = 0
        var n = 1
        while n < count {
            n *= 2
            depth += 1
        }
        return depth
    }
    
    fileprivate nonisolated static func medianCut(pixels: [Pixel], depth: Int) -> [[Pixel]] {
        guard depth > 0, pixels.count > 1 else {
            return [pixels]
        }
        
        // Find the channel with the widest range
        let rRange = pixels.map(\.r).max()! - pixels.map(\.r).min()!
        let gRange = pixels.map(\.g).max()! - pixels.map(\.g).min()!
        let bRange = pixels.map(\.b).max()! - pixels.map(\.b).min()!
        
        var sorted: [Pixel]
        if rRange >= gRange && rRange >= bRange {
            sorted = pixels.sorted { $0.r < $1.r }
        } else if gRange >= rRange && gRange >= bRange {
            sorted = pixels.sorted { $0.g < $1.g }
        } else {
            sorted = pixels.sorted { $0.b < $1.b }
        }
        
        let mid = sorted.count / 2
        let left = Array(sorted[..<mid])
        let right = Array(sorted[mid...])
        
        return medianCut(pixels: left, depth: depth - 1) + medianCut(pixels: right, depth: depth - 1)
    }
    
    fileprivate nonisolated static func averageColor(_ pixels: [Pixel]) -> Pixel {
        guard !pixels.isEmpty else { return (0, 0, 0) }
        var rSum = 0, gSum = 0, bSum = 0
        for p in pixels {
            rSum += Int(p.r)
            gSum += Int(p.g)
            bSum += Int(p.b)
        }
        let count = pixels.count
        return (UInt8(rSum / count), UInt8(gSum / count), UInt8(bSum / count))
    }
}
