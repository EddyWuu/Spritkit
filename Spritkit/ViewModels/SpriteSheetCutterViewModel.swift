//
//  SpriteSheetCutterViewModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

class SpriteSheetCutterViewModel: ObservableObject {
    
    // MARK: - Input
    
    @Published var sourceImage: CGImage?
    @Published var spriteSheet = SpriteSheet()
    
    // MARK: - Output
    
    // Cut frames as (model, image) pairs
    @Published var cutFrames: [(AnimationFrame, CGImage)] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // MARK: - Grid Controls
    
    var gridRows: Int {
        get { spriteSheet.gridRows }
        set {
            spriteSheet.gridRows = max(1, newValue)
            spriteSheet.computeGridFrames()
            objectWillChange.send()
        }
    }
    
    var gridCols: Int {
        get { spriteSheet.gridCols }
        set {
            spriteSheet.gridCols = max(1, newValue)
            spriteSheet.computeGridFrames()
            objectWillChange.send()
        }
    }
    
    var padding: Int {
        get { spriteSheet.padding }
        set {
            spriteSheet.padding = max(0, newValue)
            spriteSheet.computeGridFrames()
            objectWillChange.send()
        }
    }
    
    var sliceMode: SliceMode {
        get { spriteSheet.sliceMode }
        set {
            spriteSheet.sliceMode = newValue
            objectWillChange.send()
        }
    }
    
    // MARK: - Info
    
    var inputDimensions: String {
        guard let img = sourceImage else { return "—" }
        return img.dimensionString
    }
    
    var frameCount: Int {
        cutFrames.count
    }
    
    var frameDimensions: String {
        guard let source = sourceImage, spriteSheet.gridRows > 0, spriteSheet.gridCols > 0 else {
            return "—"
        }
        let w = (source.width - spriteSheet.padding * (spriteSheet.gridCols - 1)) / spriteSheet.gridCols
        let h = (source.height - spriteSheet.padding * (spriteSheet.gridRows - 1)) / spriteSheet.gridRows
        return "\(w)×\(h)"
    }
    
    // MARK: - Actions
    
    func sliceSheet() {
        guard let source = sourceImage else { return }
        
        // In grid mode, always recompute frames before slicing
        if spriteSheet.sliceMode == .grid {
            spriteSheet.computeGridFrames()
        }
        
        isProcessing = true
        errorMessage = nil
        
        // Capture the sheet as a value type before entering the Task
        let sheetSnapshot = spriteSheet
        
        Task.detached {
            do {
                var sheet = sheetSnapshot
                
                if sheet.sliceMode == .autoDetect {
                    let detectedFrames = try await ImageProcessingService.autoDetectFrames(image: source)
                    sheet.frames = detectedFrames
                }
                
                let results = try await ImageProcessingService.sliceSheet(image: source, sheet: sheet)
                
                await MainActor.run {
                    self.spriteSheet.frames = sheet.frames
                    self.cutFrames = results
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
    
    func setSourceImage(_ image: CGImage) {
        sourceImage = image
        spriteSheet.sourceWidth = image.width
        spriteSheet.sourceHeight = image.height
        spriteSheet.computeGridFrames()
        cutFrames = []
    }
    
    func reset() {
        sourceImage = nil
        spriteSheet = SpriteSheet()
        cutFrames = []
        errorMessage = nil
    }
}
