//
//  SpriteSheetModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics

// Defines how a sprite sheet should be sliced
nonisolated enum SliceMode: String, Codable, CaseIterable, Sendable {
    case grid       // Uniform grid (rows × cols)
    case autoDetect // Find non-transparent bounding boxes
}

// A rectangular region within a sprite sheet
nonisolated struct FrameRect: Identifiable, Codable, Sendable {
    
    let id: UUID
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    
    // Index in the animation sequence
    var index: Int
    
    init(id: UUID = UUID(), x: Int, y: Int, width: Int, height: Int, index: Int) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.index = index
    }
    
    nonisolated var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// Represents a sprite sheet — a source image and its frame definitions
nonisolated struct SpriteSheet: Identifiable, Codable, Sendable {
    
    let id: UUID
    var name: String
    var sourceWidth: Int
    var sourceHeight: Int
    var frames: [FrameRect]
    var sliceMode: SliceMode
    var createdAt: Date
    
    // Grid-mode parameters
    var gridRows: Int
    var gridCols: Int
    
    // Padding between frames (in pixels)
    var padding: Int
    
    init(
        id: UUID = UUID(),
        name: String = "Untitled Sheet",
        sourceWidth: Int = 0,
        sourceHeight: Int = 0,
        frames: [FrameRect] = [],
        sliceMode: SliceMode = .grid,
        createdAt: Date = Date(),
        gridRows: Int = 1,
        gridCols: Int = 1,
        padding: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.frames = frames
        self.sliceMode = sliceMode
        self.createdAt = createdAt
        self.gridRows = gridRows
        self.gridCols = gridCols
        self.padding = padding
    }
    
    // Compute uniform grid frames from current parameters
    mutating func computeGridFrames() {
        guard gridRows > 0, gridCols > 0 else { return }
        
        let frameWidth = (sourceWidth - padding * (gridCols - 1)) / gridCols
        let frameHeight = (sourceHeight - padding * (gridRows - 1)) / gridRows
        
        var newFrames: [FrameRect] = []
        var index = 0
        
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                let x = col * (frameWidth + padding)
                let y = row * (frameHeight + padding)
                newFrames.append(FrameRect(x: x, y: y, width: frameWidth, height: frameHeight, index: index))
                index += 1
            }
        }
        
        frames = newFrames
    }
}
