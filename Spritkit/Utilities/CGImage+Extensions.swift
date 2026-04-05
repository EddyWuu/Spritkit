//
//  CGImage+Extensions.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import UIKit

extension CGImage {
    
    // Convert to UIImage
    var uiImage: UIImage {
        UIImage(cgImage: self)
    }
    
    // Create a thumbnail with nearest-neighbor scaling (preserves pixel art)
    func thumbnail(maxDimension: Int) -> CGImage? {
        let scale: CGFloat
        if width >= height {
            scale = CGFloat(maxDimension) / CGFloat(width)
        } else {
            scale = CGFloat(maxDimension) / CGFloat(height)
        }
        
        guard scale < 1.0 else { return self } // Already small enough
        
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)
        
        guard newWidth > 0, newHeight > 0 else { return nil }
        
        let colorSpace = self.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .none
        context.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage()
    }
    
    // Get dimensions as a string (e.g., "32×32")
    var dimensionString: String {
        "\(width)×\(height)"
    }
    
    // Export to PNG data
    var pngData: Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)
        else { return nil }
        
        CGImageDestinationAddImage(destination, self, nil)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        
        return mutableData as Data
    }
}
