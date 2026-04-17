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
    
    // Selected pixelation method
    @Published var selectedMethod: PixelationMethod = .standard
    
    // MARK: - Output
    
    @Published var outputImage: CGImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // Method preview thumbnails: [method : preview CGImage]
    @Published var previews: [PixelationMethod: CGImage] = [:]
    @Published var isGeneratingPreviews = false
    
    // MARK: - Private
    
    private var previewTask: Task<Void, Never>?
    
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
    
    // Generate preview thumbnails for all methods (called when source or blockSize changes)
    func generatePreviews() {
        guard let source = sourceImage else {
            previews = [:]
            return
        }
        
        previewTask?.cancel()
        isGeneratingPreviews = true
        
        previewTask = Task {
            var newPreviews: [PixelationMethod: CGImage] = [:]
            
            for method in PixelationMethod.allCases {
                if Task.isCancelled { return }
                
                do {
                    let preview = try await ImageProcessingService.pixelatePreview(
                        image: source, blockSize: blockSize, method: method
                    )
                    if Task.isCancelled { return }
                    newPreviews[method] = preview
                    
                    // Publish incrementally so previews appear as they finish
                    await MainActor.run {
                        self.previews[method] = preview
                    }
                } catch {
                    // Skip failed previews silently
                }
            }
            
            await MainActor.run {
                self.isGeneratingPreviews = false
            }
        }
    }
    
    // Apply the selected method at full resolution
    func pixelate() {
        guard let source = sourceImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await ImageProcessingService.pixelate(
                    image: source, blockSize: blockSize, method: selectedMethod
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
        previewTask?.cancel()
        sourceImage = nil
        outputImage = nil
        blockSize = 8
        selectedMethod = .standard
        errorMessage = nil
        previews = [:]
        isGeneratingPreviews = false
    }
}
