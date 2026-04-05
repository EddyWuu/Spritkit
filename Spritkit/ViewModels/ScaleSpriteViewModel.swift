//
//  ScaleSpriteViewModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

class ScaleSpriteViewModel: ObservableObject {
    
    // MARK: - Input
    
    @Published var sourceImage: CGImage?
    
    // Scale factor (e.g., 2.0 = double size)
    @Published var scaleFactor: CGFloat = 2.0
    
    // Whether to use custom width/height instead of factor
    @Published var useCustomDimensions = false
    @Published var customWidth: Int = 64
    @Published var customHeight: Int = 64
    
    // Lock aspect ratio when using custom dimensions
    @Published var lockAspectRatio = true
    
    // MARK: - Output
    
    @Published var outputImage: CGImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // MARK: - Info
    
    var inputDimensions: String {
        guard let img = sourceImage else { return "—" }
        return img.dimensionString
    }
    
    var outputDimensions: String {
        guard let img = outputImage else { return "—" }
        return img.dimensionString
    }
    
    var previewDimensions: String {
        guard let source = sourceImage else { return "—" }
        if useCustomDimensions {
            return "\(customWidth)×\(customHeight)"
        } else {
            let w = Int(CGFloat(source.width) * scaleFactor)
            let h = Int(CGFloat(source.height) * scaleFactor)
            return "\(w)×\(h)"
        }
    }
    
    // MARK: - Actions
    
    func scale() {
        guard let source = sourceImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let factor: CGFloat
                if useCustomDimensions {
                    factor = CGFloat(customWidth) / CGFloat(source.width)
                } else {
                    factor = scaleFactor
                }
                
                let result = try await ImageProcessingService.scaleNearestNeighbor(image: source, factor: factor)
                await MainActor.run {
                    self.outputImage = result
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
    
    func updateCustomWidth(_ newWidth: Int) {
        customWidth = newWidth
        if lockAspectRatio, let source = sourceImage, source.width > 0 {
            let ratio = CGFloat(source.height) / CGFloat(source.width)
            customHeight = Int(CGFloat(newWidth) * ratio)
        }
    }
    
    func updateCustomHeight(_ newHeight: Int) {
        customHeight = newHeight
        if lockAspectRatio, let source = sourceImage, source.height > 0 {
            let ratio = CGFloat(source.width) / CGFloat(source.height)
            customWidth = Int(CGFloat(newHeight) * ratio)
        }
    }
    
    func reset() {
        sourceImage = nil
        outputImage = nil
        scaleFactor = 2.0
        useCustomDimensions = false
        customWidth = 64
        customHeight = 64
        errorMessage = nil
    }
}
