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
    
    // All frames from the cutter (the full set)
    @Published var allFrames: [(AnimationFrame, CGImage)] = []
    
    // Available animation clips
    @Published var clips: [AnimationClip] = []
    
    // Currently selected clip (nil = "All Frames")
    @Published var activeClip: AnimationClip?
    
    // MARK: - Playback State
    
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying = false
    @Published var fps: Double = 12.0 {
        didSet { restartTimerIfPlaying() }
    }
    @Published var playbackMode: PlaybackMode = .loop
    
    // For ping-pong mode
    private var isReversing = false
    
    // Timer-based playback (avoids TimelineView double-fire bug)
    private var timerCancellable: AnyCancellable?
    
    // MARK: - Computed
    
    // The frames currently being played (filtered by active clip)
    var activeFrames: [(AnimationFrame, CGImage)] {
        guard let clip = activeClip else { return allFrames }
        return clip.frameIndices.compactMap { idx in
            guard idx < allFrames.count else { return nil }
            return allFrames[idx]
        }
    }
    
    var currentImage: CGImage? {
        let frames = activeFrames
        guard !frames.isEmpty, currentFrameIndex < frames.count else { return nil }
        return frames[currentFrameIndex].1
    }
    
    var frameCount: Int { activeFrames.count }
    
    var frameDuration: TimeInterval { 1.0 / fps }
    
    var hasFrames: Bool { !activeFrames.isEmpty }
    
    var currentFrameLabel: String {
        guard hasFrames else { return "—" }
        let clipName = activeClip?.name ?? "All Frames"
        return "\(clipName) • \(currentFrameIndex + 1) / \(frameCount)"
    }
    
    var activeClipName: String {
        activeClip?.name ?? "All Frames"
    }
    
    // MARK: - Actions
    
    func play() {
        guard hasFrames else { return }
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        isPlaying = false
        stopTimer()
    }
    
    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }
    
    func stop() {
        isPlaying = false
        stopTimer()
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
    
    // MARK: - Timer
    
    private func startTimer() {
        stopTimer()
        timerCancellable = Timer.publish(every: frameDuration, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.advanceFrame()
            }
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    private func restartTimerIfPlaying() {
        if isPlaying { startTimer() }
    }
    
    // Advance to the next frame based on playback mode.
    private func advanceFrame() {
        guard hasFrames, isPlaying else { return }
        
        switch playbackMode {
        case .loop:
            currentFrameIndex = (currentFrameIndex + 1) % frameCount
            
        case .pingPong:
            if frameCount <= 1 { return }
            if isReversing {
                if currentFrameIndex <= 0 {
                    isReversing = false
                    currentFrameIndex = min(1, frameCount - 1)
                } else {
                    currentFrameIndex -= 1
                }
            } else {
                if currentFrameIndex >= frameCount - 1 {
                    isReversing = true
                    currentFrameIndex = max(frameCount - 2, 0)
                } else {
                    currentFrameIndex += 1
                }
            }
            
        case .once:
            if currentFrameIndex < frameCount - 1 {
                currentFrameIndex += 1
            } else {
                isPlaying = false
                stopTimer()
            }
        }
    }
    
    // Load all frames (no clip — plays everything)
    func loadFrames(_ newFrames: [(AnimationFrame, CGImage)]) {
        stopTimer()
        allFrames = newFrames
        activeClip = nil
        clips = []
        currentFrameIndex = 0
        isPlaying = false
        isReversing = false
    }
    
    // Load a specific clip's frames for preview
    func loadClip(_ clip: AnimationClip, frames: [(AnimationFrame, CGImage)]) {
        stopTimer()
        // Store the full frames set if we don't have them yet
        if allFrames.isEmpty {
            allFrames = frames
        }
        
        // If we don't already have this clip, add it
        if !clips.contains(where: { $0.id == clip.id }) {
            clips.append(clip)
        }
        
        activeClip = clip
        fps = clip.fps
        playbackMode = clip.playbackMode
        currentFrameIndex = 0
        isPlaying = false
        isReversing = false
    }
    
    // Load all frames with multiple clips
    func loadWithClips(_ frames: [(AnimationFrame, CGImage)], clips: [AnimationClip]) {
        stopTimer()
        allFrames = frames
        self.clips = clips
        activeClip = clips.first
        if let first = clips.first {
            fps = first.fps
            playbackMode = first.playbackMode
        }
        currentFrameIndex = 0
        isPlaying = false
        isReversing = false
    }
    
    func selectClip(_ clip: AnimationClip?) {
        stopTimer()
        isPlaying = false
        activeClip = clip
        if let clip {
            fps = clip.fps
            playbackMode = clip.playbackMode
        }
        currentFrameIndex = 0
        isReversing = false
    }
    
    func reset() {
        stopTimer()
        allFrames = []
        clips = []
        activeClip = nil
        currentFrameIndex = 0
        isPlaying = false
        fps = 12.0
        playbackMode = .loop
        isReversing = false
    }
}
