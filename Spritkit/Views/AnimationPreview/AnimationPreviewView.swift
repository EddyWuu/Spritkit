//
//  AnimationPreviewView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

struct AnimationPreviewView: View {
    
    @ObservedObject var viewModel: AnimationPreviewViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Animation canvas
                canvasSection
                
                Divider()
                
                // Timeline strip
                if viewModel.hasFrames {
                    timelineStrip
                    Divider()
                }
                
                // Playback controls
                controlsSection
            }
            .navigationTitle("Animation Preview")
        }
    }
    
    // MARK: - Canvas
    
    @ViewBuilder
    private var canvasSection: some View {
        if let image = viewModel.currentImage {
            TimelineView(.periodic(from: .now, by: viewModel.frameDuration)) { timeline in
                SpriteCanvasView(image: image)
                    .onChange(of: timeline.date) { _, _ in
                        viewModel.advanceFrame()
                    }
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Text(viewModel.currentFrameLabel)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
        } else {
            ContentUnavailableView {
                Label("No Frames Loaded", systemImage: "play.rectangle")
            } description: {
                Text("Use the Sheet Cutter to slice a sprite sheet, then preview the animation here.")
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    // MARK: - Timeline Strip
    
    private var timelineStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(viewModel.frames.enumerated()), id: \.offset) { index, pair in
                    Image(decorative: pair.1, scale: 1.0)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .background(CheckerboardView().opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    index == viewModel.currentFrameIndex ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .onTapGesture {
                            viewModel.pause()
                            viewModel.currentFrameIndex = index
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 60)
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Playback buttons
            HStack(spacing: 20) {
                Button { viewModel.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.hasFrames)
                
                Button { viewModel.stepBackward() } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.hasFrames)
                
                Button { viewModel.togglePlayback() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .disabled(!viewModel.hasFrames)
                
                Button { viewModel.stepForward() } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.hasFrames)
            }
            
            // FPS slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speed")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(viewModel.fps)) FPS")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $viewModel.fps, in: 1...60, step: 1) {
                    Text("FPS")
                } minimumValueLabel: {
                    Text("1").font(.caption2)
                } maximumValueLabel: {
                    Text("60").font(.caption2)
                }
            }
            
            // Playback mode picker
            Picker("Mode", selection: $viewModel.playbackMode) {
                ForEach(PlaybackMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    AnimationPreviewView(viewModel: AnimationPreviewViewModel())
}
