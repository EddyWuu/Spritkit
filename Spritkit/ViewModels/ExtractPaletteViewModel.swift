//
//  ExtractPaletteViewModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

class ExtractPaletteViewModel: ObservableObject {
    
    // MARK: - Input
    
    @Published var sourceImage: CGImage?
    
    // Maximum number of colors to extract
    @Published var maxColors: Int = 16
    
    // MARK: - Output
    
    @Published var palette: Palette?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // Currently selected color for detail view
    @Published var selectedColor: PaletteColor?
    
    // MARK: - Info
    
    var inputDimensions: String {
        guard let img = sourceImage else { return "—" }
        return img.dimensionString
    }
    
    var colorCount: Int {
        palette?.colorCount ?? 0
    }
    
    // MARK: - Presets
    
    static let colorPresets = [4, 8, 16, 32, 64, 128]
    
    // MARK: - Actions
    
    func extractPalette() {
        guard let source = sourceImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await ImageProcessingService.extractPalette(image: source, maxColors: maxColors)
                await MainActor.run {
                    self.palette = result
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
        palette = nil
        maxColors = 16
        errorMessage = nil
        selectedColor = nil
    }
}
