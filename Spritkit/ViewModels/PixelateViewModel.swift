//
//  PixelateViewModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

class PixelateViewModel: ObservableObject {
    
    // MARK: - Input
    
    @Published var sourceImage: CGImage?
    
    // Pixel block size — higher values = more pixelated
    @Published var blockSize: CGFloat = 8
    
    // Target palette size for palette-based methods (Standard, K-Means, Quantize, Dither)
    @Published var colorCount: Int = 16
    
    // Selected pixelation method
    @Published var selectedMethod: PixelationMethod = .standard
    
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
    
    // MARK: - Actions
    
    // Apply the selected method at full resolution
    func pixelate() {
        guard let source = sourceImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await ImageProcessingService.pixelate(
                    image: source, blockSize: blockSize, method: selectedMethod, colorCount: colorCount
                )
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
    
    func reset() {
        sourceImage = nil
        outputImage = nil
        blockSize = 8
        colorCount = 16
        selectedMethod = .standard
        errorMessage = nil
    }
}
