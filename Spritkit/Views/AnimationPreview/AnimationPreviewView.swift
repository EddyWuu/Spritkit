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
                // Clip picker (if multiple clips available)
                if !viewModel.clips.isEmpty {
                    clipPicker
                    Divider()
                }
                
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
            .toolbar {
                if viewModel.hasFrames {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) {
                            viewModel.reset()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle.fill")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - Clip Picker
    
    private var clipPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All Frames" option
                clipChip(name: "All Frames", color: .gray, isActive: viewModel.activeClip == nil) {
                    viewModel.selectClip(nil)
                }
                
                // Individual clips
                ForEach(viewModel.clips) { clip in
                    clipChip(name: clip.name, color: clip.colorTag.color, isActive: viewModel.activeClip?.id == clip.id) {
                        viewModel.selectClip(clip)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private func clipChip(name: String, color: Color, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.caption.weight(isActive ? .bold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isActive ? color.opacity(0.2) : Color(uiColor: .tertiarySystemBackground),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Canvas
    
    @ViewBuilder
    private var canvasSection: some View {
        if let image = viewModel.currentImage {
            SpriteCanvasView(image: image)
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
                ForEach(Array(viewModel.activeFrames.enumerated()), id: \.offset) { index, pair in
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
