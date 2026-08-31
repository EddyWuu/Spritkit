//
//  AnimationPreviewView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

struct AnimationPreviewView: View {
    
    @ObservedObject var viewModel: AnimationPreviewViewModel
    @State private var showingHelp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.clips.isEmpty {
                    clipPicker
                }
                
                canvasSection
                
                if viewModel.hasFrames {
                    timelineStrip
                }
                
                controlsSection
            }
            .background(Theme.ink)
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
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpSheetView.animationPreview
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Clip Picker
    
    private var clipPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                clipChip(name: "All Frames", color: Theme.steel, isActive: viewModel.activeClip == nil) {
                    viewModel.selectClip(nil)
                }
                
                ForEach(viewModel.clips) { clip in
                    clipChip(name: clip.name, color: clip.colorTag.color, isActive: viewModel.activeClip?.id == clip.id) {
                        viewModel.selectClip(clip)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.steelDark).frame(height: 1) }
    }
    
    private func clipChip(name: String, color: Color, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.pixel(11, weight: isActive ? .heavy : .medium))
            }
            .foregroundStyle(isActive ? Theme.onDark : Theme.onDarkDim)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(isActive ? color.opacity(0.25) : Theme.panelLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(isActive ? color : Theme.steelDark, lineWidth: isActive ? 2 : 1)
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
                    PixelBadge {
                        Text(viewModel.currentFrameLabel)
                            .font(.pixel(11, weight: .bold))
                            .foregroundStyle(Theme.onDark)
                    }
                    .padding(8)
                }
        } else {
            PixelEmptyState(
                icon: "play.rectangle",
                title: "No Frames Loaded",
                message: "Use the Sheet Cutter to slice a sprite sheet, then preview the animation here."
            ) {
                EmptyView()
            }
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
                        .background(CheckerboardView())
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(
                                    index == viewModel.currentFrameIndex ? Theme.accent : Theme.steelDark,
                                    lineWidth: index == viewModel.currentFrameIndex ? 3 : 1
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
        .frame(height: 62)
        .background(Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(Theme.steelDark).frame(height: 1) }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                Button { viewModel.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.onDark)
                }
                .disabled(!viewModel.hasFrames)
                
                Button { viewModel.stepBackward() } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.onDark)
                }
                .disabled(!viewModel.hasFrames)
                
                Button { viewModel.togglePlayback() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .fill(Theme.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(.black.opacity(0.35), lineWidth: Theme.border)
                        )
                        .foregroundStyle(.white)
                }
                .disabled(!viewModel.hasFrames)
                
                Button { viewModel.stepForward() } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.onDark)
                }
                .disabled(!viewModel.hasFrames)
            }
            .opacity(viewModel.hasFrames ? 1 : 0.4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PixelSectionHeader(title: "Speed")
                    Text("\(Int(viewModel.fps)) FPS")
                        .font(.pixel(13, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
                
                Slider(value: $viewModel.fps, in: 1...60, step: 1)
                    .tint(Theme.accent)
            }
            
            Picker("Mode", selection: $viewModel.playbackMode) {
                ForEach(PlaybackMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Theme.ink)
    }
}

#Preview {
    AnimationPreviewView(viewModel: AnimationPreviewViewModel())
}
