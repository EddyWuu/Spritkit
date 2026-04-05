//
//  AnimationPreviewViewModel.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

class AnimationPreviewViewModel: ObservableObject {
    
    // MARK: - Input
    
    // The frames to animate (typically from SpriteSheetCutter output)
    @Published var frames: [(AnimationFrame, CGImage)] = []
    
    // MARK: - Playback State
    
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying = false
    @Published var fps: Double = 12.0
    @Published var playbackMode: PlaybackMode = .loop
    
    // For ping-pong mode
    private var isReversing = false
    
    // MARK: - Computed
    
    var currentImage: CGImage? {
        guard !frames.isEmpty, currentFrameIndex < frames.count else { return nil }
        return frames[currentFrameIndex].1
    }
    
    var frameCount: Int { frames.count }
    
    var frameDuration: TimeInterval { 1.0 / fps }
    
    var hasFrames: Bool { !frames.isEmpty }
    
    var currentFrameLabel: String {
        guard hasFrames else { return "—" }
        return "\(currentFrameIndex + 1) / \(frameCount)"
    }
    
    // MARK: - Actions
    
    func play() {
        guard hasFrames else { return }
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }
    
    func stop() {
        isPlaying = false
        currentFrameIndex = 0
        isReversing = false
    }
    
    func stepForward() {
        guard hasFrames else { return }
        currentFrameIndex = (currentFrameIndex + 1) % frameCount
    }
    
    func stepBackward() {
        guard hasFrames else { return }
        currentFrameIndex = currentFrameIndex > 0 ? currentFrameIndex - 1 : frameCount - 1
    }
    
    // Advance to the next frame based on playback mode.
    // Called by the TimelineView on each tick.
    func advanceFrame() {
        guard hasFrames, isPlaying else { return }
        
        switch playbackMode {
        case .loop:
            currentFrameIndex = (currentFrameIndex + 1) % frameCount
            
        case .pingPong:
            if isReversing {
                if currentFrameIndex <= 0 {
                    isReversing = false
                    currentFrameIndex = 1
                } else {
                    currentFrameIndex -= 1
                }
            } else {
                if currentFrameIndex >= frameCount - 1 {
                    isReversing = true
                    currentFrameIndex = frameCount - 2
                } else {
                    currentFrameIndex += 1
                }
            }
            
        case .once:
            if currentFrameIndex < frameCount - 1 {
                currentFrameIndex += 1
            } else {
                isPlaying = false
            }
        }
    }
    
    func loadFrames(_ newFrames: [(AnimationFrame, CGImage)]) {
        frames = newFrames
        currentFrameIndex = 0
        isPlaying = false
        isReversing = false
    }
    
    func reset() {
        frames = []
        currentFrameIndex = 0
        isPlaying = false
        fps = 12.0
        playbackMode = .loop
        isReversing = false
    }
}
