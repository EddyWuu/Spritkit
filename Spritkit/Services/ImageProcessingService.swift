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

// Stateless, nonisolated image processing service. All work runs off the main thread.
nonisolated enum ImageProcessingService {

    // MARK: - Internal Helper Types
    
    private struct KSum { var r: Double = 0; var g: Double = 0; var b: Double = 0; var count: Int = 0 }
    private struct RGBA { var r: UInt8; var g: UInt8; var b: UInt8; var a: UInt8 }

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - Pixelate (Unified Dispatcher)
    
    // colorCount is the target palette size (2...64) for palette-based methods.
    static func pixelate(image: CGImage, blockSize: CGFloat, method: PixelationMethod = .standard, colorCount: Int = 16) async throws -> CGImage {
        let clamped = min(max(blockSize, 1), 256)
        let colors = min(max(colorCount, 2), 64)
        // Normalize to canonical RGBA so BGRA sources don't come out blue.
        let src = normalizedImage(image) ?? image
        
        switch method {
        case .standard:         return try await pixelateStandard(image: src, blockSize: clamped, colorCount: colors)
        case .kuwaharaFilter:   return try await pixelateKuwahara(image: src, blockSize: clamped)
        case .kMeansClustering: return try await pixelateKMeans(image: src, blockSize: clamped, colorCount: colors)
        case .quantizeUpscale:  return try await pixelateQuantizeUpscale(image: src, blockSize: clamped, colorCount: colors)
        case .edgeDetection:    return try await detectEdges(image: src, blockSize: clamped)
        case .dither:           return try await pixelateDither(image: src, blockSize: clamped, colorCount: colors)
        }
    }
    
    // Generate a small preview thumbnail using a given method (for method picker).
    static func pixelatePreview(image: CGImage, blockSize: CGFloat, method: PixelationMethod, colorCount: Int = 16, maxDimension: Int = 120) async throws -> CGImage {
        let scale = CGFloat(maxDimension) / CGFloat(max(image.width, image.height))
        let thumb: CGImage
        if scale < 1.0 {
            thumb = try await scaleNearestNeighbor(image: image, factor: scale)
        } else {
            thumb = image
        }
        let thumbBlock = max(2, blockSize * scale)
        return try await pixelate(image: thumb, blockSize: thumbBlock, method: method, colorCount: colorCount)
    }
    
    // MARK: - Standard (Downscale + Palette + Upscale)
    
    // Shrink to block resolution, reduce to a median-cut palette, upscale nearest.
    private static func pixelateStandard(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await pixelateStandard(image: image, blockSize: blockSize, colorCount: 16)
    }
    
    private static func pixelateStandard(image: CGImage, blockSize: CGFloat, colorCount: Int) async throws -> CGImage {
        return try await Task.detached {
            let origW = image.width
            let origH = image.height
            let block = max(Int(blockSize), 1)
            let smallW = max(origW / block, 1)
            let smallH = max(origH / block, 1)
            
            guard let small = normalizedRGBA(from: image, exactWidth: smallW, exactHeight: smallH) else {
                throw ProcessingError.pixelAccessFailed
            }
            var buf = small.pixels
            
            applyPalette(to: &buf, width: smallW, height: smallH, colorCount: colorCount)
            
            let smallImg = try renderRGBA(pixels: &buf, width: smallW, height: smallH)
            return try nearestUpscale(smallImg, toWidth: origW, toHeight: origH)
        }.value
    }
    
    // MARK: - Kuwahara Filter
    
    // Uses the lowest-variance quadrant of each pixel's neighborhood. Edge-preserving, painterly.
    private static func pixelateKuwahara(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let origW = image.width
            let origH = image.height
            // Cap working resolution and radius so it stays fast on large photos.
            guard let norm = normalizedRGBA(from: image, maxDimension: 720) else {
                throw ProcessingError.pixelAccessFailed
            }
            let pixels = norm.pixels
            let w = norm.width
            let h = norm.height
            let radius = max(1, min(Int(blockSize / 2), 6))
            
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            
            for y in 0..<h {
                for x in 0..<w {
                    let quads: [(xRange: ClosedRange<Int>, yRange: ClosedRange<Int>)] = [
                        (max(0, x - radius)...x, max(0, y - radius)...y),
                        (x...min(w - 1, x + radius), max(0, y - radius)...y),
                        (max(0, x - radius)...x, y...min(h - 1, y + radius)),
                        (x...min(w - 1, x + radius), y...min(h - 1, y + radius))
                    ]
                    
                    var bestVariance = Double.greatestFiniteMagnitude
                    var bestR = 0.0, bestG = 0.0, bestB = 0.0, bestA = 0.0
                    
                    for quad in quads {
                        var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumA = 0.0
                        var sumR2 = 0.0, sumG2 = 0.0, sumB2 = 0.0
                        var count = 0.0
                        
                        for qy in quad.yRange {
                            for qx in quad.xRange {
                                let off = (qy * w + qx) * 4
                                let r = Double(pixels[off])
                                let g = Double(pixels[off + 1])
                                let b = Double(pixels[off + 2])
                                sumR += r; sumG += g; sumB += b; sumA += Double(pixels[off + 3])
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
            
            let small = try renderRGBA(pixels: &outPixels, width: w, height: h)
            return try nearestUpscale(small, toWidth: origW, toHeight: origH)
        }.value
    }
    
    // MARK: - K-Means Clustering
    
    // Clusters colors via K-Means, then maps each block to its nearest centroid.
    private static func pixelateKMeans(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await pixelateKMeans(image: image, blockSize: blockSize, colorCount: 16)
    }
    
    private static func pixelateKMeans(image: CGImage, blockSize: CGFloat, colorCount: Int) async throws -> CGImage {
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

            // For large blocks or huge images, aggregate pixels into block cells and
            // run K-Means on those averages to cut the sample count dramatically.
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
                let maxSamples = 200_000
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
                    // Strided sampling to cap total samples.
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

            var k = max(2, min(colorCount, 32))
            k = min(k, max(2, samples.count / 4))

            // k-means++ init: spread initial centroids apart for stable, vibrant results.
            var centroids: [(r: Double, g: Double, b: Double, a: Double)] = []
            centroids.reserveCapacity(k)
            let first = samples[samples.count / 2]
            centroids.append((first.r, first.g, first.b, first.a))
            var dist = [Double](repeating: Double.greatestFiniteMagnitude, count: samples.count)
            while centroids.count < k {
                let last = centroids[centroids.count - 1]
                var total = 0.0
                for (i, s) in samples.enumerated() {
                    let dr = s.r - last.r, dg = s.g - last.g, db = s.b - last.b
                    let d = dr * dr + dg * dg + db * db
                    if d < dist[i] { dist[i] = d }
                    total += dist[i]
                }
                guard total > 0 else { break }
                var target = Double.random(in: 0..<total)
                var chosen = samples.count - 1
                for (i, d) in dist.enumerated() {
                    target -= d
                    if target <= 0 { chosen = i; break }
                }
                let s = samples[chosen]
                centroids.append((s.r, s.g, s.b, s.a))
            }
            k = centroids.count

            let maxIters = 8
            var assignments = [Int](repeating: -1, count: samples.count)
            for _ in 0..<maxIters {
                var changed = false
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

                for i in 0..<k {
                    if sums[i].count > 0 {
                        let n = Double(sums[i].count)
                        centroids[i] = (sums[i].r / n, sums[i].g / n, sums[i].b / n, 255.0)
                    }
                }

                if !changed { break }
            }

            var outPixels = [UInt8](repeating: 0, count: w * h * 4)

            if useBlockAggregation {
                let centroidBytes: [RGBA] = centroids.map { c in
                    RGBA(r: UInt8(clamping: Int(c.r)), g: UInt8(clamping: Int(c.g)), b: UInt8(clamping: Int(c.b)), a: 255)
                }

                for by in 0..<blocksY {
                    let y0 = by * block
                    let y1 = min(h, y0 + block)
                    for bx in 0..<blocksX {
                        let x0 = bx * block
                        let x1 = min(w, x0 + block)
                        let sampleIdx = by * blocksX + bx
                        let assigned: Int = {
                            if sampleIdx < assignments.count {
                                return assignments[sampleIdx]
                            } else {
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
    
    // Lanczos downscale, reduce to a median-cut palette, upscale nearest.
    private static func pixelateQuantizeUpscale(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await pixelateQuantizeUpscale(image: image, blockSize: blockSize, colorCount: 16)
    }
    
    private static func pixelateQuantizeUpscale(image: CGImage, blockSize: CGFloat, colorCount: Int) async throws -> CGImage {
        return try await Task.detached {
            let w = image.width
            let h = image.height
            let block = max(Int(blockSize), 2)
            let smallW = max(w / block, 1)
            let smallH = max(h / block, 1)
            
            let ciImage = CIImage(cgImage: image)
            let scaleX = Double(smallW) / Double(w)
            let scaleY = Double(smallH) / Double(h)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            guard let smallCG = ciContext.createCGImage(scaled, from: scaled.extent) else {
                throw ProcessingError.renderFailed
            }
            
            // Normalize first — CIContext output may be BGRA.
            guard let norm = normalizedRGBA(from: smallCG) else {
                throw ProcessingError.pixelAccessFailed
            }
            var buf = norm.pixels
            applyPalette(to: &buf, width: norm.width, height: norm.height, colorCount: colorCount)
            
            let smallResult = try renderRGBA(pixels: &buf, width: norm.width, height: norm.height)
            
            return try nearestUpscale(smallResult, toWidth: w, toHeight: h)
        }.value
    }
    
    // MARK: - Floyd-Steinberg Dither
    
    // Reduces to a median-cut palette with Floyd-Steinberg error diffusion, then upscales.
    private static func pixelateDither(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await pixelateDither(image: image, blockSize: blockSize, colorCount: 16)
    }
    
    private static func pixelateDither(image: CGImage, blockSize: CGFloat, colorCount: Int) async throws -> CGImage {
        return try await Task.detached {
            let origW = image.width
            let origH = image.height
            let block = max(Int(blockSize), 1)
            let w = max(origW / block, 1)
            let h = max(origH / block, 1)
            
            guard let small = normalizedRGBA(from: image, exactWidth: w, exactHeight: h) else {
                throw ProcessingError.pixelAccessFailed
            }
            
            let palette = buildPalette(from: small.pixels, width: w, height: h, colorCount: colorCount)
            guard !palette.isEmpty else { throw ProcessingError.pixelAccessFailed }
            
            // Work in floating point so error can accumulate.
            var work = [Double](repeating: 0, count: w * h * 3)
            var alpha = [UInt8](repeating: 255, count: w * h)
            for i in 0..<(w * h) {
                let o = i * 4
                work[i * 3]     = Double(small.pixels[o])
                work[i * 3 + 1] = Double(small.pixels[o + 1])
                work[i * 3 + 2] = Double(small.pixels[o + 2])
                alpha[i] = small.pixels[o + 3]
            }
            
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            
            for y in 0..<h {
                for x in 0..<w {
                    let i = y * w + x
                    let oldR = work[i * 3], oldG = work[i * 3 + 1], oldB = work[i * 3 + 2]
                    let pi = nearestPaletteIndex(r: oldR, g: oldG, b: oldB, palette: palette)
                    let np = palette[pi]
                    let nr = Double(np.r), ng = Double(np.g), nb = Double(np.b)
                    
                    let outOff = i * 4
                    outPixels[outOff]     = np.r
                    outPixels[outOff + 1] = np.g
                    outPixels[outOff + 2] = np.b
                    outPixels[outOff + 3] = alpha[i]
                    
                    let errR = oldR - nr, errG = oldG - ng, errB = oldB - nb
                    func spread(_ dx: Int, _ dy: Int, _ factor: Double) {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { return }
                        let ni = (ny * w + nx) * 3
                        work[ni]     += errR * factor
                        work[ni + 1] += errG * factor
                        work[ni + 2] += errB * factor
                    }
                    spread(1, 0, 7.0 / 16.0)
                    spread(-1, 1, 3.0 / 16.0)
                    spread(0, 1, 5.0 / 16.0)
                    spread(1, 1, 1.0 / 16.0)
                }
            }
            
            let smallImg = try renderRGBA(pixels: &outPixels, width: w, height: h)
            return try nearestUpscale(smallImg, toWidth: origW, toHeight: origH)
        }.value
    }
    
    // MARK: - Edge Detection (Sobel Overlay)
    
    // Sobel edges blended over the original. blockSize acts as a pre-blur radius.
    private static func detectEdges(image: CGImage, blockSize: CGFloat) async throws -> CGImage {
        return try await Task.detached {
            let origW = image.width
            let origH = image.height
            guard let norm = normalizedRGBA(from: image, maxDimension: 1400) else {
                throw ProcessingError.pixelAccessFailed
            }
            let pixels = norm.pixels
            let w = norm.width
            let h = norm.height
            
            var luma = [Double](repeating: 0, count: w * h)
            for i in 0..<(w * h) {
                let o = i * 4
                luma[i] = 0.299 * Double(pixels[o]) + 0.587 * Double(pixels[o + 1]) + 0.114 * Double(pixels[o + 2])
            }
            
            // Optional light box blur to reduce noise.
            let blurRadius = max(0, min(2, Int(blockSize / 12)))
            if blurRadius > 0 {
                var blurred = luma
                for y in 0..<h {
                    for x in 0..<w {
                        var sum = 0.0, cnt = 0.0
                        let ys = max(0, y - blurRadius), ye = min(h - 1, y + blurRadius)
                        let xs = max(0, x - blurRadius), xe = min(w - 1, x + blurRadius)
                        for ny in ys...ye {
                            for nx in xs...xe {
                                sum += luma[ny * w + nx]; cnt += 1
                            }
                        }
                        blurred[y * w + x] = sum / cnt
                    }
                }
                luma = blurred
            }
            
            // Sobel gradient magnitude, blended white over the original color.
            var outPixels = [UInt8](repeating: 0, count: w * h * 4)
            for y in 0..<h {
                for x in 0..<w {
                    let xm = max(0, x - 1), xp = min(w - 1, x + 1)
                    let ym = max(0, y - 1), yp = min(h - 1, y + 1)
                    
                    let tl = luma[ym * w + xm], tc = luma[ym * w + x], tr = luma[ym * w + xp]
                    let ml = luma[y * w + xm],  mr = luma[y * w + xp]
                    let bl = luma[yp * w + xm], bc = luma[yp * w + x], br = luma[yp * w + xp]
                    
                    let gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl)
                    let gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr)
                    let mag = min(1.0, sqrt(gx * gx + gy * gy) / 255.0)
                    
                    let o = (y * w + x) * 4
                    let oR = Double(pixels[o]), oG = Double(pixels[o + 1]), oB = Double(pixels[o + 2])
                    outPixels[o]     = UInt8(clamping: Int(oR + (255.0 - oR) * mag))
                    outPixels[o + 1] = UInt8(clamping: Int(oG + (255.0 - oG) * mag))
                    outPixels[o + 2] = UInt8(clamping: Int(oB + (255.0 - oB) * mag))
                    outPixels[o + 3] = pixels[o + 3]
                }
            }
            
            let small = try renderRGBA(pixels: &outPixels, width: w, height: h)
            return try nearestUpscale(small, toWidth: origW, toHeight: origH)
        }.value
    }
    
    // MARK: - Normalized Pixel Access
    
    // Redraws into a canonical RGBA8 buffer (bytes are R,G,B,A), fixing BGRA channel order.
    private static func normalizedImage(_ image: CGImage) -> CGImage? {
        let w = image.width
        let h = image.height
        guard w > 0, h > 0, let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs, bitmapInfo: bitmapInfo) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
    
    // Draws a CGImage into a raw RGBA8 array, optionally downsampling to a max long side.
    private static func normalizedRGBA(from image: CGImage, maxDimension: Int? = nil) -> (pixels: [UInt8], width: Int, height: Int)? {
        var w = image.width
        var h = image.height
        if let maxDim = maxDimension, maxDim > 0, max(w, h) > maxDim {
            let scale = Double(maxDim) / Double(max(w, h))
            w = max(1, Int((Double(image.width) * scale).rounded()))
            h = max(1, Int((Double(image.height) * scale).rounded()))
        }
        guard w > 0, h > 0, let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let success: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: cs, bitmapInfo: bitmapInfo) else { return false }
            ctx.interpolationQuality = (maxDimension != nil) ? .high : .none
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return success ? (pixels, w, h) : nil
    }
    
    // Draws a CGImage into a raw RGBA8 buffer at an exact target size (high-quality downscale).
    private static func normalizedRGBA(from image: CGImage, exactWidth: Int, exactHeight: Int) -> (pixels: [UInt8], width: Int, height: Int)? {
        let w = max(1, exactWidth)
        let h = max(1, exactHeight)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let success: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: cs, bitmapInfo: bitmapInfo) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return success ? (pixels, w, h) : nil
    }
    
    // MARK: - Palette Quantization Helpers
    
    private typealias PColor = (r: UInt8, g: UInt8, b: UInt8)
    
    // Build a cohesive palette from an RGBA buffer using median-cut.
    private static func buildPalette(from pixels: [UInt8], width: Int, height: Int, colorCount: Int) -> [PColor] {
        var samples: [Pixel] = []
        samples.reserveCapacity(width * height)
        for i in 0..<(width * height) {
            let o = i * 4
            if pixels[o + 3] == 0 { continue }
            samples.append((pixels[o], pixels[o + 1], pixels[o + 2]))
        }
        guard !samples.isEmpty else { return [] }
        let buckets = medianCut(pixels: samples, depth: depthForCount(max(2, colorCount)))
        // Average each bucket, then dedupe identical colors.
        var seen = Set<Int>()
        var palette: [PColor] = []
        for bucket in buckets where !bucket.isEmpty {
            let avg = averageColor(bucket)
            let key = Int(avg.r) << 16 | Int(avg.g) << 8 | Int(avg.b)
            if seen.insert(key).inserted {
                palette.append((avg.r, avg.g, avg.b))
            }
        }
        return palette
    }
    
    // Index of the nearest palette color to an (r,g,b) triple.
    private static func nearestPaletteIndex(r: Double, g: Double, b: Double, palette: [PColor]) -> Int {
        var best = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, c) in palette.enumerated() {
            let dr = r - Double(c.r), dg = g - Double(c.g), db = b - Double(c.b)
            let d = dr * dr + dg * dg + db * db
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }
    
    // Reduce an RGBA buffer to a median-cut palette in place (hard mapping).
    private static func applyPalette(to pixels: inout [UInt8], width: Int, height: Int, colorCount: Int) {
        let palette = buildPalette(from: pixels, width: width, height: height, colorCount: colorCount)
        guard !palette.isEmpty else { return }
        for i in 0..<(width * height) {
            let o = i * 4
            if pixels[o + 3] == 0 { continue }
            let idx = nearestPaletteIndex(r: Double(pixels[o]), g: Double(pixels[o + 1]), b: Double(pixels[o + 2]), palette: palette)
            let c = palette[idx]
            pixels[o] = c.r; pixels[o + 1] = c.g; pixels[o + 2] = c.b
        }
    }
    private static func nearestUpscale(_ image: CGImage, toWidth: Int, toHeight: Int) throws -> CGImage {
        guard toWidth > 0, toHeight > 0 else { throw ProcessingError.renderFailed }
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: toWidth, height: toHeight,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ProcessingError.renderFailed
        }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: toWidth, height: toHeight))
        guard let result = ctx.makeImage() else { throw ProcessingError.renderFailed }
        return result
    }
    
    // MARK: - Render Helper
    
    // Render an RGBA pixel buffer into a CGImage.
    private static func renderRGBA(pixels: inout [UInt8], width: Int, height: Int) throws -> CGImage {        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { throw ProcessingError.renderFailed }
        let ctx = CGContext(data: &pixels, width: width, height: height,
                           bitsPerComponent: 8, bytesPerRow: width * 4, space: cs,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let result = ctx?.makeImage() else { throw ProcessingError.renderFailed }
        return result
    }
    
    // MARK: - Scale (Nearest Neighbor)
    
    // Scale using nearest-neighbor to preserve pixel-art crispness. factor clamped to 0.1...32.
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
            
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            
            guard let result = context.makeImage() else {
                throw ProcessingError.renderFailed
            }
            
            return result
        }.value
    }
    
    // MARK: - Extract Palette (Median Cut)
    
    // Extract dominant colors via median-cut, sorted by frequency.
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
            
            var pixels: [(r: UInt8, g: UInt8, b: UInt8)] = []
            pixels.reserveCapacity(width * height)
            
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    let r = ptr[offset]
                    let g = ptr[offset + 1]
                    let b = ptr[offset + 2]
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
            
            let buckets = medianCut(pixels: pixels, depth: depthForCount(maxColors))
            
            var colors: [PaletteColor] = buckets.map { bucket in
                let avg = averageColor(bucket)
                return PaletteColor(
                    red: Double(avg.r) / 255.0,
                    green: Double(avg.g) / 255.0,
                    blue: Double(avg.b) / 255.0,
                    frequency: bucket.count
                )
            }
            
            // Merge buckets that averaged to the same hex color.
            var seen: [String: Int] = [:]
            var deduped: [PaletteColor] = []
            for color in colors {
                if let existingIdx = seen[color.hex] {
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
            
            colors.sort { $0.frequency > $1.frequency }
            
            if colors.count > maxColors {
                colors = Array(colors.prefix(maxColors))
            }
            
            return Palette(name: "Extracted Palette", colors: colors)
        }.value
    }
    
    // MARK: - Sprite Sheet Slicing
    
    // Slice a sprite sheet into frames (call computeGridFrames() first for grid mode).
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
    
    // Detect sprite bounding boxes by finding connected non-transparent regions.
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
            
            var visited = Array(repeating: false, count: width * height)
            var frames: [FrameRect] = []
            
            func isOpaque(x: Int, y: Int) -> Bool {
                let offset = y * bytesPerRow + x * bytesPerPixel
                return ptr[offset + 3] > 10
            }
            
            for y in 0..<height {
                for x in 0..<width {
                    let idx = y * width + x
                    if visited[idx] || !isOpaque(x: x, y: y) { continue }
                    
                    // BFS to find this region's bounding box.
                    var minX = x, maxX = x, minY = y, maxY = y
                    var queue = [(x, y)]
                    visited[idx] = true
                    
                    while !queue.isEmpty {
                        let (cx, cy) = queue.removeFirst()
                        minX = min(minX, cx)
                        maxX = max(maxX, cx)
                        minY = min(minY, cy)
                        maxY = max(maxY, cy)
                        
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
                    
                    // Ignore stray specks.
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
        
        // Split on the widest-range channel.
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
