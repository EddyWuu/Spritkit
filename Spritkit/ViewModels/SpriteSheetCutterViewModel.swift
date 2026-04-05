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
    
    // MARK: - Frame Selection (for creating animation clips)
    
    @Published var selectedFrameIndices: Set<Int> = []
    @Published var isSelectingFrames = false
    
    // MARK: - Clip Management
    
    @Published var clips: [AnimationClip] = []
    @Published var showingCreateClip = false
    @Published var newClipName = ""
    @Published var newClipColor: ClipColor = .blue
    
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
    
    // Which clip "owns" a given frame index (for coloring the strip)
    func clipColor(for frameIndex: Int) -> Color? {
        for clip in clips {
            if clip.frameIndices.contains(frameIndex) {
                return clip.colorTag.color
            }
        }
        return nil
    }
    
    // MARK: - Frame Selection Actions
    
    func toggleFrameSelection(_ index: Int) {
        if selectedFrameIndices.contains(index) {
            selectedFrameIndices.remove(index)
        } else {
            selectedFrameIndices.insert(index)
        }
    }
    
    func selectAll() {
        selectedFrameIndices = Set(0..<cutFrames.count)
    }
    
    func deselectAll() {
        selectedFrameIndices.removeAll()
    }
    
    func selectRange(from start: Int, to end: Int) {
        let range = min(start, end)...max(start, end)
        selectedFrameIndices = Set(range)
    }
    
    // MARK: - Clip Actions
    
    func createClipFromSelection() {
        guard !selectedFrameIndices.isEmpty else { return }
        
        let sorted = selectedFrameIndices.sorted()
        let name = newClipName.isEmpty ? "Animation \(clips.count + 1)" : newClipName
        
        let clip = AnimationClip(
            name: name,
            frameIndices: sorted,
            colorTag: newClipColor
        )
        
        clips.append(clip)
        spriteSheet.clips = clips
        
        // Reset selection state
        selectedFrameIndices.removeAll()
        newClipName = ""
        
        // Cycle to next color
        let allColors = ClipColor.allCases
        if let currentIdx = allColors.firstIndex(of: newClipColor) {
            newClipColor = allColors[(currentIdx + 1) % allColors.count]
        }
    }
    
    func deleteClip(_ clip: AnimationClip) {
        clips.removeAll { $0.id == clip.id }
        spriteSheet.clips = clips
    }
    
    func deleteClip(at offsets: IndexSet) {
        clips.remove(atOffsets: offsets)
        spriteSheet.clips = clips
    }
    
    // MARK: - Slice Actions
    
    func sliceSheet() {
        guard let source = sourceImage else { return }
        
        // In grid mode, always recompute frames before slicing
        if spriteSheet.sliceMode == .grid {
            spriteSheet.computeGridFrames()
        }
        
        isProcessing = true
        errorMessage = nil
        
        // Clear previous clips and selection when re-slicing
        clips.removeAll()
        selectedFrameIndices.removeAll()
        
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
        clips = []
        selectedFrameIndices.removeAll()
    }
    
    func reset() {
        sourceImage = nil
        spriteSheet = SpriteSheet()
        cutFrames = []
        clips = []
        selectedFrameIndices.removeAll()
        errorMessage = nil
        newClipName = ""
        isSelectingFrames = false
    }
}
