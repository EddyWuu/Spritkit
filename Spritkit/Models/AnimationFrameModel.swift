//
//  AnimationFrameModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import SwiftUI

// A single frame in a sprite animation.
nonisolated struct AnimationFrame: Identifiable, Codable, Sendable {
    
    let id: UUID
    var index: Int
    var duration: TimeInterval
    var width: Int
    var height: Int
    var imageFilename: String
    
    init(
        id: UUID = UUID(),
        index: Int,
        duration: TimeInterval = 1.0 / 12.0,
        width: Int = 0,
        height: Int = 0,
        imageFilename: String = ""
    ) {
        self.id = id
        self.index = index
        self.duration = duration
        self.width = width
        self.height = height
        self.imageFilename = imageFilename
    }
}

// A named subset of a sheet's frames forming one animation (e.g. "Walk"),
// inspired by Aseprite's "tags".
nonisolated struct AnimationClip: Identifiable, Codable, Sendable {
    
    let id: UUID
    var name: String
    // Indices into the parent sheet's cut frames array
    var frameIndices: [Int]
    var fps: Double
    var playbackMode: PlaybackMode
    var colorTag: ClipColor
    
    init(
        id: UUID = UUID(),
        name: String = "Untitled",
        frameIndices: [Int] = [],
        fps: Double = 12.0,
        playbackMode: PlaybackMode = .loop,
        colorTag: ClipColor = .blue
    ) {
        self.id = id
        self.name = name
        self.frameIndices = frameIndices
        self.fps = fps
        self.playbackMode = playbackMode
        self.colorTag = colorTag
    }
    
    var frameCount: Int { frameIndices.count }
}

// Color options for animation clip tags.
nonisolated enum ClipColor: String, Codable, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, pink
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}

// Playback mode for animation preview.
nonisolated enum PlaybackMode: String, Codable, CaseIterable, Identifiable {
    case loop
    case pingPong
    case once
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .loop: return "Loop"
        case .pingPong: return "Ping-Pong"
        case .once: return "Once"
        }
    }
}
