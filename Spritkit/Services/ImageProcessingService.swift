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
    

    // MARK: - Internal Helper Types
    
    private struct KSum { var r: Double = 0; var g: Double = 0; var b: Double = 0; var count: Int = 0 }
    private struct CenterSum { var x: Double = 0; var y: Double = 0; var l: Double = 0; var a: Double = 0; var b: Double = 0; var count: Int = 0 }
    private struct ClusterSum { var r: Double = 0; var g: Double = 0; var b: Double = 0; var a: Double = 0; var count: Int = 0 }
    private struct RGBA { var r: UInt8; var g: UInt8; var b: UInt8; var a: UInt8 }
    private struct VoronoiSeed {
        var x: Int; var y: Int
        var sumR: Double = 0; var sumG: Double = 0; var sumB: Double = 0; var sumA: Double = 0
        var count: Int = 0
    }
    private struct PixelLab { var l: Double; var a: Double; var b: Double }
    private struct SLICCenter { var x: Double; var y: Double; var l: Double; var a: Double; var b: Double }
    // MARK: - Shared CIContext (reuse for performance)
    
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - Pixelate (Unified Dispatcher)
    
    // Apply a pixelation method to an image.
    static func pixelate(image: CGImage, blockSize: CGFloat, method: PixelationMethod = .standard) async throws -> CGImage {
        let clamped = min(max(blockSize, 1), 256)
        
        switch method {
        case .standard:         return try await pixelateStandard(image: image, blockSize: clamped)
        case .kuwaharaFilter:   return try await pixelateKuwahara(image: image, blockSize: clamped)
        case .kMeansClustering: return try await pixelateKMeans(image: image, blockSize: clamped)
        case .quantizeUpscale:  return try await pixelateQuantizeUpscale(image: image, blockSize: clamped)
        case .bilateralGrid:    return try await pixelateBilateralGrid(image: image, blockSize: clamped)
        case .voronoi:          return try await pixelateVoronoi(image: image, blockSize: clamped)
        case .superpixelSLIC:   return try await pixelateSLIC(image: image, blockSize: clamped)
        case .edgeDetection:    return try await detectEdges(image: image, blockSize: clamped)
        case .dither:           return try await pixelateDither(image: image, blockSize: clamped)
        }
    }
    
    // Generate a small preview thumbnail using a given method (for method picker).
    static func pixelatePreview(image: CGImage, blockSize: CGFloat, method: PixelationMethod, maxDimension: Int = 120) async throws -> CGImage {
        // Downscale source first for speed
        let scale = CGFloat(maxDimension) / CGFloat(max(image.width, image.height))
        let thumb: CGImage
        if scale < 1.0 {
            thumb = try await scaleNearestNeighbor(image: image, factor: scale)
        } else {
            thumb = image
        }
        let thumbBlock = max(2, blockSize * scale)
        return try await pixelate(image: thumb, blockSize: thumbBlock, method: method)
    }
    
    // MARK: - Standard (CIPixellate)
    
    private static func pixelateStandard(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let ciImage = CIImage(cgImage: image)
            
            guard let filter = CIFilter(name: "CIPixellate") else {
                throw ProcessingError.filterUnavailable("CIPixellate")
            }
            
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(blockSize, forKey: kCIInputScaleKey)
            filter.setValue(CIVector(x: 0, y: 0), forKey: kCIInputCenterKey)
            
            guard let output = filter.outputImage else {
                throw ProcessingError.filterFailed("CIPixellate produced no output")
            }
            
            let cropped = output.cropped(to: ciImage.extent)
            
            guard let cgResult = ciContext.createCGImage(cropped, from: cropped.extent) else {
                throw ProcessingError.renderFailed
            }
            
            return cgResult
        }.value
    }
    
    // MARK: - Kuwahara Filter
    
    // Divides each pixel's neighborhood into 4 quadrants, uses the one with lowest variance.
    // Edge-preserving, produces a painterly/blocky look.
    private static func pixelateKuwahara(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let radius = max(Int(blockSize / 2), 1)
            
            guard let inData = image.dataProvider?.data,
                  let inPtr = CFDataGetBytePtr(inData) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow
            
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            
            for y in 0..<h {
                for x in 0..<w {
                    // Define 4 quadrants around (x, y)
                    let quads: [(xRange: ClosedRange<Int>, yRange: ClosedRange<Int>)] = [
                        (max(0, x - radius)...x, max(0, y - radius)...y),       // top-left
                        (x...min(w - 1, x + radius), max(0, y - radius)...y),   // top-right
                        (max(0, x - radius)...x, y...min(h - 1, y + radius)),   // bottom-left
                        (x...min(w - 1, x + radius), y...min(h - 1, y + radius)) // bottom-right
                    ]
                    
                    var bestVariance = Double.greatestFiniteMagnitude
                    var bestR = 0.0, bestG = 0.0, bestB = 0.0, bestA = 0.0
                    
                    for quad in quads {
                        var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumA = 0.0
                        var sumR2 = 0.0, sumG2 = 0.0, sumB2 = 0.0
                        var count = 0.0
                        
                        for qy in quad.yRange {
                            for qx in quad.xRange {
                                let off = qy * bpr + qx * bpp
                                let r = Double(inPtr[off])
                                let g = Double(inPtr[off + 1])
                                let b = Double(inPtr[off + 2])
                                let a = bpp >= 4 ? Double(inPtr[off + 3]) : 255.0
                                sumR += r; sumG += g; sumB += b; sumA += a
                                sumR2 += r * r; sumG2 += g * g; sumB2 += b * b
                                count += 1
                            }
                        }
                        
                        if count > 0 {
                            let avgR = sumR / count
                            let avgG = sumG / count
                            let avgB = sumB / count
                            let variance = (sumR2 / count - avgR * avgR) +
                                           (sumG2 / count - avgG * avgG) +
                                           (sumB2 / count - avgB * avgB)
                            
                            if variance < bestVariance {
                                bestVariance = variance
                                bestR = avgR; bestG = avgG; bestB = avgB
                                bestA = sumA / count
                            }
                        }
                    }
                    
                    let outOff = (y * w + x) * 4
                    outPixels[outOff]     = UInt8(clamping: Int(bestR))
                    outPixels[outOff + 1] = UInt8(clamping: Int(bestG))
                    outPixels[outOff + 2] = UInt8(clamping: Int(bestB))
                    outPixels[outOff + 3] = UInt8(clamping: Int(bestA))
                }
            }
            
            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - K-Means Clustering
    
    // Clusters colors via K-Means, then maps each block to the nearest cluster centroid.
    // Edges stay sharper because similar-colored regions stay cohesive.
    private static func pixelateKMeans(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let block = max(Int(blockSize), 1)

            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }

            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow

            // If the block size is large relative to the image, or the image is huge,
            // aggregate pixels into block cells and run K-Means on those averages
            // This reduces sample count from w*h down to (w/block)*(h/block)
            let useBlockAggregation = block >= 4 || (w * h) > 1_000_000

            var samples: [(r: Double, g: Double, b: Double, a: Double)] = []
            var blocksX = 0, blocksY = 0

            if useBlockAggregation {
                blocksX = max(1, (w + block - 1) / block)
                blocksY = max(1, (h + block - 1) / block)
                samples.reserveCapacity(blocksX * blocksY)

                for by in 0..<blocksY {
                    let y0 = by * block
                    let y1 = min(h, y0 + block)
                    for bx in 0..<blocksX {
                        let x0 = bx * block
                        let x1 = min(w, x0 + block)
                        var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumA = 0.0
                        var cnt = 0.0
                        for y in y0..<y1 {
                            for x in x0..<x1 {
                                let off = y * bpr + x * bpp
                                sumR += Double(ptr[off])
                                sumG += Double(ptr[off + 1])
                                sumB += Double(ptr[off + 2])
                                sumA += bpp >= 4 ? Double(ptr[off + 3]) : 255.0
                                cnt += 1
                            }
                        }
                        if cnt > 0 {
                            samples.append((sumR / cnt, sumG / cnt, sumB / cnt, sumA / cnt))
                        }
                    }
                }
            } else {
                // Small block: sample pixels but cap total samples for performance
                let maxSamples = 200_000 // safe upper bound for per-pixel sampling
                let total = w * h
                if total <= maxSamples {
                    samples.reserveCapacity(total)
                    for y in 0..<h {
                        for x in 0..<w {
                            let off = y * bpr + x * bpp
                            samples.append((Double(ptr[off]), Double(ptr[off + 1]), Double(ptr[off + 2]), bpp >= 4 ? Double(ptr[off + 3]) : 255.0))
                        }
                    }
                } else {
                    // Strided sampling: pick an approximate sqrt stride to limit samples
                    let sampleStride = Int(sqrt(Double(total) / Double(maxSamples)))
                    let step = max(1, sampleStride)
                    for y in stride(from: 0, to: h, by: step) {
                        for x in stride(from: 0, to: w, by: step) {
                            let off = y * bpr + x * bpp
                            samples.append((Double(ptr[off]), Double(ptr[off + 1]), Double(ptr[off + 2]), bpp >= 4 ? Double(ptr[off + 3]) : 255.0))
                        }
                    }
                }
            }

            guard !samples.isEmpty else { throw ProcessingError.pixelAccessFailed }

            // Decide k (number of clusters) and cap it reasonably
            var k = max(2, min(16, Int((w * h) / (block * block))))
            k = min(k, max(2, samples.count / 4))

            // Initialize centroids by evenly picking samples
            var centroids: [(r: Double, g: Double, b: Double, a: Double)] = []
            centroids.reserveCapacity(k)
            let step = max(1, samples.count / k)
            for i in 0..<k {
                let idx = min(i * step, samples.count - 1)
                let s = samples[idx]
                centroids.append((s.r, s.g, s.b, s.a))
            }

            // K-Means iterations with caps and early exit
            let maxIters = 8
            var assignments = [Int](repeating: -1, count: samples.count)
            for _ in 0..<maxIters {
                var changed = false

                // reset sums
                var sums = [KSum](repeating: KSum(), count: k)

                for (i, px) in samples.enumerated() {
                    var bestDist = Double.greatestFiniteMagnitude
                    var bestIdx = 0
                    for (ci, c) in centroids.enumerated() {
                        let dr = px.r - c.r; let dg = px.g - c.g; let db = px.b - c.b
                        let d = dr * dr + dg * dg + db * db
                        if d < bestDist { bestDist = d; bestIdx = ci }
                    }
                    if assignments[i] != bestIdx { changed = true }
                    assignments[i] = bestIdx
                    sums[bestIdx].r += px.r
                    sums[bestIdx].g += px.g
                    sums[bestIdx].b += px.b
                    sums[bestIdx].count += 1
                }

                // update centroids
                for i in 0..<k {
                    if sums[i].count > 0 {
                        let n = Double(sums[i].count)
                        centroids[i] = (sums[i].r / n, sums[i].g / n, sums[i].b / n, 255.0)
                    }
                }

                if !changed { break }
            }

            // Now paint output: if we used blockAggregation, map each block to nearest centroid and fill full block.
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)

            if useBlockAggregation {
                // compute centroid colors as RGBA bytes
                let centroidBytes: [RGBA] = centroids.map { c in
                    RGBA(r: UInt8(clamping: Int(c.r)), g: UInt8(clamping: Int(c.g)), b: UInt8(clamping: Int(c.b)), a: 255)
                }

                for by in 0..<blocksY {
                    let y0 = by * block
                    let y1 = min(h, y0 + block)
                    for bx in 0..<blocksX {
                        let x0 = bx * block
                        let x1 = min(w, x0 + block)
                        // find sample index corresponding to this block
                        let sampleIdx = by * blocksX + bx
                        let assigned: Int = {
                            if sampleIdx < assignments.count {
                                return assignments[sampleIdx]
                            } else {
                                // fallback: nearest centroid by distance
                                let s = samples[min(sampleIdx, samples.count - 1)]
                                var bestDist = Double.greatestFiniteMagnitude
                                var bestIdx = 0
                                for (ci, c) in centroids.enumerated() {
                                    let dr = s.r - c.r; let dg = s.g - c.g; let db = s.b - c.b
                                    let d = dr * dr + dg * dg + db * db
                                    if d < bestDist { bestDist = d; bestIdx = ci }
                                }
                                return bestIdx
                            }
                        }()

                        let col = centroidBytes[max(0, min(centroidBytes.count - 1, assigned))]
                        for y in y0..<y1 {
                            for x in x0..<x1 {
                                let outOff = (y * w + x) * 4
                                outPixels[outOff] = col.r
                                outPixels[outOff + 1] = col.g
                                outPixels[outOff + 2] = col.b
                                outPixels[outOff + 3] = col.a
                            }
                        }
                    }
                }
            } else {
                // Per-pixel block-average then snap to centroid (original behavior optimized)
                // Block-average then map to nearest centroid
                for by in stride(from: 0, to: h, by: block) {
                    for bx in stride(from: 0, to: w, by: block) {
                        var avgR = 0.0, avgG = 0.0, avgB = 0.0, avgA = 0.0, cnt = 0.0
                        let endY = min(by + block, h)
                        let endX = min(bx + block, w)

                        for y in by..<endY {
                            for x in bx..<endX {
                                let off = y * bpr + x * bpp
                                avgR += Double(ptr[off])
                                avgG += Double(ptr[off + 1])
                                avgB += Double(ptr[off + 2])
                                avgA += bpp >= 4 ? Double(ptr[off + 3]) : 255.0
                                cnt += 1
                            }
                        }
                        avgR /= cnt; avgG /= cnt; avgB /= cnt; avgA /= cnt

                        // find nearest centroid
                        var bestDist = Double.greatestFiniteMagnitude
                        var bestC = centroids[0]
                        for c in centroids {
                            let dr = avgR - c.r; let dg = avgG - c.g; let db = avgB - c.b
                            let d = dr * dr + dg * dg + db * db
                            if d < bestDist { bestDist = d; bestC = c }
                        }

                        for y in by..<endY {
                            for x in bx..<endX {
                                let outOff = (y * w + x) * 4
                                outPixels[outOff] = UInt8(clamping: Int(bestC.r))
                                outPixels[outOff + 1] = UInt8(clamping: Int(bestC.g))
                                outPixels[outOff + 2] = UInt8(clamping: Int(bestC.b))
                                outPixels[outOff + 3] = UInt8(clamping: Int(avgA))
                            }
                        }
                    }
                }
            }

            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - Quantize + Upscale
    
    // Downscale aggressively with Lanczos, quantize colors, upscale with nearest neighbor.
    private static func pixelateQuantizeUpscale(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let block = max(Int(blockSize), 2)
            let smallW = max(w / block, 1)
            let smallH = max(h / block, 1)
            
            // 1. Downscale with Lanczos (high quality)
            let ciImage = CIImage(cgImage: image)
            let scaleX = Double(smallW) / Double(w)
            let scaleY = Double(smallH) / Double(h)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            guard let smallCG = ciContext.createCGImage(scaled, from: scaled.extent) else {
                throw ProcessingError.renderFailed
            }
            
            // 2. Quantize colors (reduce to 16 levels per channel)
            guard let data = smallCG.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = smallCG.bitsPerPixel / 8
            let bpr = smallCG.bytesPerRow
            var quantized = [UInt8](repeating: 0, count: smallW * smallH * 4)
            
            for y in 0..<smallH {
                for x in 0..<smallW {
                    let off = y * bpr + x * bpp
                    let outOff = (y * smallW + x) * 4
                    // Quantize to 16 levels (round to nearest multiple of 17)
                    quantized[outOff]     = UInt8(min(255, (Int(ptr[off]) / 17) * 17))
                    quantized[outOff + 1] = UInt8(min(255, (Int(ptr[off + 1]) / 17) * 17))
                    quantized[outOff + 2] = UInt8(min(255, (Int(ptr[off + 2]) / 17) * 17))
                    quantized[outOff + 3] = bpp >= 4 ? ptr[off + 3] : 255
                }
            }
            
            let smallResult = try renderRGBA(pixels: &quantized, width: smallW, height: smallH)
            
            // 3. Upscale with nearest neighbor
            let upscaleFactor = CGFloat(block)
            guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: nil, width: w, height: h,
                                     bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw ProcessingError.renderFailed
            }
            ctx.interpolationQuality = .none
            ctx.draw(smallResult, in: CGRect(x: 0, y: 0, width: CGFloat(smallW) * upscaleFactor,
                                              height: CGFloat(smallH) * upscaleFactor))
            
            guard let result = ctx.makeImage() else { throw ProcessingError.renderFailed }
            return result
        }.value
    }
    
    // MARK: - Bilateral Filter + Grid
    
    // Bilateral filter smooths flat regions while preserving edges, then block-average.
    private static func pixelateBilateralGrid(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let block = max(Int(blockSize), 1)
            
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow
            let spatialSigma = Double(block)
            let colorSigma = 30.0
            let radius = max(Int(blockSize / 2), 2)
            
            // 1. Bilateral filter pass
            var filtered = [UInt8](repeating: 0, count: w * h * 4)
            
            for y in 0..<h {
                for x in 0..<w {
                    let centerOff = y * bpr + x * bpp
                    let cR = Double(ptr[centerOff])
                    let cG = Double(ptr[centerOff + 1])
                    let cB = Double(ptr[centerOff + 2])
                    let cA = bpp >= 4 ? ptr[centerOff + 3] : UInt8(255)
                    
                    var wSum = 0.0, rSum = 0.0, gSum = 0.0, bSum = 0.0
                    
                    let yStart = max(0, y - radius)
                    let yEnd = min(h - 1, y + radius)
                    let xStart = max(0, x - radius)
                    let xEnd = min(w - 1, x + radius)
                    
                    for ny in yStart...yEnd {
                        for nx in xStart...xEnd {
                            let nOff = ny * bpr + nx * bpp
                            let nR = Double(ptr[nOff])
                            let nG = Double(ptr[nOff + 1])
                            let nB = Double(ptr[nOff + 2])
                            
                            let spatialDist = Double((nx - x) * (nx - x) + (ny - y) * (ny - y))
                            let colorDist = (nR - cR) * (nR - cR) + (nG - cG) * (nG - cG) + (nB - cB) * (nB - cB)
                            
                            let weight = exp(-spatialDist / (2 * spatialSigma * spatialSigma)) *
                                         exp(-colorDist / (2 * colorSigma * colorSigma))
                            
                            wSum += weight
                            rSum += nR * weight
                            gSum += nG * weight
                            bSum += nB * weight
                        }
                    }
                    
                    let outOff = (y * w + x) * 4
                    filtered[outOff]     = UInt8(clamping: Int(rSum / wSum))
                    filtered[outOff + 1] = UInt8(clamping: Int(gSum / wSum))
                    filtered[outOff + 2] = UInt8(clamping: Int(bSum / wSum))
                    filtered[outOff + 3] = cA
                }
            }
            
            // 2. Block-average the filtered result
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            
            for by in stride(from: 0, to: h, by: block) {
                for bx in stride(from: 0, to: w, by: block) {
                    var avgR = 0.0, avgG = 0.0, avgB = 0.0, avgA = 0.0, cnt = 0.0
                    let endY = min(by + block, h)
                    let endX = min(bx + block, w)
                    
                    for y in by..<endY {
                        for x in bx..<endX {
                            let off = (y * w + x) * 4
                            avgR += Double(filtered[off])
                            avgG += Double(filtered[off + 1])
                            avgB += Double(filtered[off + 2])
                            avgA += Double(filtered[off + 3])
                            cnt += 1
                        }
                    }
                    avgR /= cnt; avgG /= cnt; avgB /= cnt; avgA /= cnt
                    
                    for y in by..<endY {
                        for x in bx..<endX {
                            let outOff = (y * w + x) * 4
                            outPixels[outOff]     = UInt8(clamping: Int(avgR))
                            outPixels[outOff + 1] = UInt8(clamping: Int(avgG))
                            outPixels[outOff + 2] = UInt8(clamping: Int(avgB))
                            outPixels[outOff + 3] = UInt8(clamping: Int(avgA))
                        }
                    }
                }
            }
            
            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - Voronoi Pixelation
    
    // Place seed points on a grid (jittered), color each pixel by nearest seed's average.
    private static func pixelateVoronoi(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let block = max(Int(blockSize), 2)
            
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow
            
            // Generate jittered grid seeds
            var seeds: [VoronoiSeed] = []
            let jitter = block / 4
            for sy in stride(from: block / 2, to: h, by: block) {
                for sx in stride(from: block / 2, to: w, by: block) {
                    let jx = sx + Int.random(in: -jitter...jitter)
                    let jy = sy + Int.random(in: -jitter...jitter)
                    seeds.append(VoronoiSeed(x: min(max(jx, 0), w - 1), y: min(max(jy, 0), h - 1)))
                }
            }
            
            // Assign each pixel to its nearest seed
            var assignments = [Int](repeating: 0, count: w * h)
            
            for y in 0..<h {
                for x in 0..<w {
                    var bestDist = Int.max
                    var bestIdx = 0
                    for (i, s) in seeds.enumerated() {
                        let d = (x - s.x) * (x - s.x) + (y - s.y) * (y - s.y)
                        if d < bestDist { bestDist = d; bestIdx = i }
                    }
                    assignments[y * w + x] = bestIdx
                    
                    let off = y * bpr + x * bpp
                    seeds[bestIdx].sumR += Double(ptr[off])
                    seeds[bestIdx].sumG += Double(ptr[off + 1])
                    seeds[bestIdx].sumB += Double(ptr[off + 2])
                    seeds[bestIdx].sumA += bpp >= 4 ? Double(ptr[off + 3]) : 255.0
                    seeds[bestIdx].count += 1
                }
            }
            
            // Compute average color per seed, then paint
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            
            let seedColors: [RGBA] = seeds.map { s in
                guard s.count > 0 else { return RGBA(r: 0, g: 0, b: 0, a: 255) }
                let n = Double(s.count)
                return RGBA(r: UInt8(clamping: Int(s.sumR / n)),
                            g: UInt8(clamping: Int(s.sumG / n)),
                            b: UInt8(clamping: Int(s.sumB / n)),
                            a: UInt8(clamping: Int(s.sumA / n)))
            }
            
            for y in 0..<h {
                for x in 0..<w {
                    let sIdx = assignments[y * w + x]
                    let c = seedColors[sIdx]
                    let off = (y * w + x) * 4
                    outPixels[off] = c.r; outPixels[off + 1] = c.g
                    outPixels[off + 2] = c.b; outPixels[off + 3] = c.a
                }
            }
            
            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - Superpixel SLIC
    
    // Simplified SLIC: seeds on grid, iteratively refine assignments based on
    // spatial + color distance. Produces irregular cells that follow image content.
    private static func pixelateSLIC(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let S = max(Int(blockSize), 2) // grid spacing
            let m = 10.0 // compactness
            
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow
            
            // Read all pixels into Lab-like space (just use RGB scaled for speed)
            var lab = [PixelLab](repeating: PixelLab(l: 0, a: 0, b: 0), count: w * h)
            for y in 0..<h {
                for x in 0..<w {
                    let off = y * bpr + x * bpp
                    lab[y * w + x] = PixelLab(l: Double(ptr[off]), a: Double(ptr[off + 1]), b: Double(ptr[off + 2]))
                }
            }
            
            // Initialize cluster centers on grid
            var centers: [SLICCenter] = []
            for cy in stride(from: S / 2, to: h, by: S) {
                for cx in stride(from: S / 2, to: w, by: S) {
                    let p = lab[cy * w + cx]
                    centers.append(SLICCenter(x: Double(cx), y: Double(cy), l: p.l, a: p.a, b: p.b))
                }
            }
            
            var labels = [Int](repeating: -1, count: w * h)
            var distances = [Double](repeating: .greatestFiniteMagnitude, count: w * h)
            
            // 4 SLIC iterations (sufficient for visual quality)
            for _ in 0..<4 {
                distances = [Double](repeating: .greatestFiniteMagnitude, count: w * h)
                
                for (ci, c) in centers.enumerated() {
                    let xMin = max(0, Int(c.x) - S)
                    let xMax = min(w - 1, Int(c.x) + S)
                    let yMin = max(0, Int(c.y) - S)
                    let yMax = min(h - 1, Int(c.y) + S)
                    
                    for y in yMin...yMax {
                        for x in xMin...xMax {
                            let p = lab[y * w + x]
                            let dc = (p.l - c.l) * (p.l - c.l) + (p.a - c.a) * (p.a - c.a) + (p.b - c.b) * (p.b - c.b)
                            let ds = (Double(x) - c.x) * (Double(x) - c.x) + (Double(y) - c.y) * (Double(y) - c.y)
                            let D = dc + (m * m / Double(S * S)) * ds
                            
                            if D < distances[y * w + x] {
                                distances[y * w + x] = D
                                labels[y * w + x] = ci
                            }
                        }
                    }
                }
                
                // Update centers
                var sums = [CenterSum](repeating: CenterSum(), count: centers.count)
                for y in 0..<h {
                    for x in 0..<w {
                        let ci = labels[y * w + x]
                        guard ci >= 0 else { continue }
                        let p = lab[y * w + x]
                        sums[ci].x += Double(x); sums[ci].y += Double(y)
                        sums[ci].l += p.l; sums[ci].a += p.a; sums[ci].b += p.b
                        sums[ci].count += 1
                    }
                }
                for i in 0..<centers.count {
                    if sums[i].count > 0 {
                        let n = Double(sums[i].count)
                        centers[i] = SLICCenter(x: sums[i].x / n, y: sums[i].y / n,
                                            l: sums[i].l / n, a: sums[i].a / n, b: sums[i].b / n)
                    }
                }
            }
            
            // Paint each pixel with its cluster's average color (from original image)
            var clusterSums = [ClusterSum](repeating: ClusterSum(), count: centers.count)
            for y in 0..<h {
                for x in 0..<w {
                    let ci = labels[y * w + x]
                    guard ci >= 0 else { continue }
                    let off = y * bpr + x * bpp
                    clusterSums[ci].r += Double(ptr[off])
                    clusterSums[ci].g += Double(ptr[off + 1])
                    clusterSums[ci].b += Double(ptr[off + 2])
                    clusterSums[ci].a += bpp >= 4 ? Double(ptr[off + 3]) : 255.0
                    clusterSums[ci].count += 1
                }
            }
            
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            let clusterColors: [RGBA] = clusterSums.map { s in
                guard s.count > 0 else { return RGBA(r: 0, g: 0, b: 0, a: 255) }
                let n = Double(s.count)
                return RGBA(r: UInt8(clamping: Int(s.r / n)),
                             g: UInt8(clamping: Int(s.g / n)),
                             b: UInt8(clamping: Int(s.b / n)),
                             a: UInt8(clamping: Int(s.a / n)))
            }
            
            for y in 0..<h {
                for x in 0..<w {
                    let ci = labels[y * w + x]
                    let c = ci >= 0 ? clusterColors[ci] : RGBA(r: 0, g: 0, b: 0, a: 255)
                    let off = (y * w + x) * 4
                    outPixels[off] = c.r; outPixels[off + 1] = c.g
                    outPixels[off + 2] = c.b; outPixels[off + 3] = c.a
                }
            }
            
            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - Edge Detection (Sobel)
    
    // Sobel edge detection — produces white edges on black background.
    // blockSize controls a pre-blur to reduce noise (higher = fewer edges).
    private static func detectEdges(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow
            
            // Convert to grayscale
            var gray = [Double](repeating: 0, count: w * h)
            for y in 0..<h {
                for x in 0..<w {
                    let off = y * bpr + x * bpp
                    gray[y * w + x] = 0.299 * Double(ptr[off]) + 0.587 * Double(ptr[off + 1]) + 0.114 * Double(ptr[off + 2])
                }
            }
            
            // Optional box blur based on blockSize (reduces noise)
            let blurRadius = max(Int(blockSize / 4), 0)
            if blurRadius > 0 {
                var blurred = gray
                for y in 0..<h {
                    for x in 0..<w {
                        var sum = 0.0, cnt = 0.0
                        for dy in -blurRadius...blurRadius {
                            for dx in -blurRadius...blurRadius {
                                let nx = x + dx, ny = y + dy
                                if nx >= 0 && nx < w && ny >= 0 && ny < h {
                                    sum += gray[ny * w + nx]
                                    cnt += 1
                                }
                            }
                        }
                        blurred[y * w + x] = sum / cnt
                    }
                }
                gray = blurred
            }
            
            // Sobel operator -> produce edge magnitude map
            var magMap = [UInt8](repeating: 0, count: w * h)
            var maxMag = 0.0
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let tl = gray[(y - 1) * w + (x - 1)]
                    let t  = gray[(y - 1) * w + x]
                    let tr = gray[(y - 1) * w + (x + 1)]
                    let l  = gray[y * w + (x - 1)]
                    let r  = gray[y * w + (x + 1)]
                    let bl = gray[(y + 1) * w + (x - 1)]
                    let b  = gray[(y + 1) * w + x]
                    let br = gray[(y + 1) * w + (x + 1)]
                    
                    let gx = -tl - 2 * l - bl + tr + 2 * r + br
                    let gy = -tl - 2 * t - tr + bl + 2 * b + br
                    let mag = sqrt(gx * gx + gy * gy)
                    if mag > maxMag { maxMag = mag }
                    magMap[y * w + x] = UInt8(min(255, Int(mag)))
                }
            }
            
            // Normalize and composite edges over the original image so we keep color context
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            // Avoid divide-by-zero
            let norm = maxMag > 0 ? maxMag : 1.0
            for y in 0..<h {
                for x in 0..<w {
                    let offSrc = y * bpr + x * bpp
                    let origR = Double(ptr[offSrc])
                    let origG = Double(ptr[offSrc + 1])
                    let origB = Double(ptr[offSrc + 2])
                    let origA = bpp >= 4 ? Double(ptr[offSrc + 3]) : 255.0
                    
                    let mag = Double(magMap[y * w + x])
                    // edgeStrength in 0..1 using normalized magnitude
                    let edgeStrength = min(1.0, mag / norm)
                    // boost contrast of edges slightly
                    let strength = pow(edgeStrength, 0.9) * 1.0
                    
                    // Blend white edge over original color: out = lerp(orig, white, strength)
                    let outR = (1.0 - strength) * origR + strength * 255.0
                    let outG = (1.0 - strength) * origG + strength * 255.0
                    let outB = (1.0 - strength) * origB + strength * 255.0
                    
                    let outOff = (y * w + x) * 4
                    outPixels[outOff]     = UInt8(clamping: Int(outR))
                    outPixels[outOff + 1] = UInt8(clamping: Int(outG))
                    outPixels[outOff + 2] = UInt8(clamping: Int(outB))
                    outPixels[outOff + 3] = UInt8(clamping: Int(origA))
                }
            }
            
            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - Ordered Dither (Bayer)
    
    // 4×4 Bayer ordered dithering with reduced color palette. Classic retro look.
    private static func pixelateDither(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            
            guard let data = image.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let bpp = image.bitsPerPixel / 8
            let bpr = image.bytesPerRow
            
            // 4x4 Bayer matrix (normalized to 0...1)
            let bayer: [[Double]] = [
                [ 0.0/16, 8.0/16, 2.0/16, 10.0/16],
                [12.0/16, 4.0/16, 14.0/16,  6.0/16],
                [ 3.0/16, 11.0/16, 1.0/16,  9.0/16],
                [15.0/16, 7.0/16, 13.0/16,  5.0/16]
            ]
            
            // Number of color levels derived from blockSize (fewer levels = more retro)
            let levels = max(2, min(16, 18 - Int(blockSize / 4)))
            let step = 255.0 / Double(levels - 1)
            
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            
            for y in 0..<h {
                for x in 0..<w {
                    let off = y * bpr + x * bpp
                    let threshold = (bayer[y % 4][x % 4] - 0.5) * step
                    
                    let r = Double(ptr[off]) + threshold
                    let g = Double(ptr[off + 1]) + threshold
                    let b = Double(ptr[off + 2]) + threshold
                    let a = bpp >= 4 ? ptr[off + 3] : UInt8(255)
                    
                    // Quantize to nearest level
                    let qR = UInt8(clamping: Int(round(r / step) * step))
                    let qG = UInt8(clamping: Int(round(g / step) * step))
                    let qB = UInt8(clamping: Int(round(b / step) * step))
                    
                    let outOff = (y * w + x) * 4
                    outPixels[outOff] = qR; outPixels[outOff + 1] = qG
                    outPixels[outOff + 2] = qB; outPixels[outOff + 3] = a
                }
            }
            
            return try renderRGBA(pixels: &outPixels, width: w, height: h)
        }.value
    }
    
    // MARK: - Render Helper
    
    // Render an RGBA pixel buffer into a CGImage.
    private static func renderRGBA(pixels: inout [UInt8], width: Int, height: Int) throws -> CGImage {
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { throw ProcessingError.renderFailed }
        let ctx = CGContext(data: &pixels, width: width, height: height,
                           bitsPerComponent: 8, bytesPerRow: width * 4, space: cs,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let result = ctx?.makeImage() else { throw ProcessingError.renderFailed }
        return result
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
