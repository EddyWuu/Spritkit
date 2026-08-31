//
//  SpriteSheetCutterView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI
import UIKit

struct SpriteSheetCutterView: View {
    
    @StateObject private var viewModel = SpriteSheetCutterViewModel()
    @ObservedObject var animationVM: AnimationPreviewViewModel
    var onSendToAnimate: () -> Void
    @State private var importedImage: CGImage?
    @State private var savedFrameIndex: Int?
    @State private var showingSaveAllConfirm = false
    @State private var showingHelp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasSection
                
                if !viewModel.cutFrames.isEmpty {
                    framesStrip
                }
                
                if !viewModel.clips.isEmpty {
                    clipsSection
                }
                
                controlsSection
            }
            .background(Theme.ink)
            .navigationTitle("Sheet Cutter")
            .toolbar {
                if viewModel.sourceImage != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) {
                            importedImage = nil
                            viewModel.reset()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle.fill")
                        }
                        .tint(.red)
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    
                    ImagePickerView(
                        selectedImage: $importedImage,
                        label: "Import",
                        systemImage: "photo.badge.plus"
                    )
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpSheetView.spriteSheetCutter
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: importedImage) { _, newImage in
                if let img = newImage {
                    viewModel.setSourceImage(img)
                }
            }
            .sheet(isPresented: $viewModel.showingCreateClip) {
                createClipSheet
            }
        }
    }
    
    // MARK: - Canvas
    
    @ViewBuilder
    private var canvasSection: some View {
        if let image = viewModel.sourceImage {
            SpriteCanvasView(
                image: image,
                showGrid: viewModel.sliceMode == .grid,
                gridRows: viewModel.gridRows,
                gridCols: viewModel.gridCols
            )
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                PixelBadge {
                    HStack(spacing: 8) {
                        Text(viewModel.inputDimensions)
                            .foregroundStyle(Theme.onDark)
                        if viewModel.sliceMode == .grid {
                            Text("FRAME \(viewModel.frameDimensions)")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .font(.pixel(11, weight: .bold))
                }
                .padding(8)
            }
            .overlay {
                if viewModel.isProcessing {
                    VStack(spacing: 10) {
                        ProgressView().tint(Theme.accent)
                        Text("SLICING…")
                            .font(.pixel(11, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.onDark)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .fill(Theme.panel)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(Theme.steelDark, lineWidth: Theme.border))
                    )
                }
            }
        } else {
            PixelEmptyState(
                icon: "rectangle.split.3x3",
                title: "No Sprite Sheet",
                message: "Import a sprite sheet to slice it into individual frames."
            ) {
                ImagePickerView(
                    selectedImage: $importedImage,
                    label: "Select Sheet",
                    systemImage: "photo.badge.plus"
                )
                .buttonStyle(PixelButtonStyle())
                .fixedSize()
            }
        }
    }
    
    // MARK: - Frames Strip (selectable)
    
    private var framesStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(viewModel.frameCount) FRAMES")
                    .font(.pixel(11, weight: .heavy))
                    .foregroundStyle(Theme.onDark)
                
                Spacer()
                
                if !viewModel.selectedFrameIndices.isEmpty {
                    Text("\(viewModel.selectedFrameIndices.count) SELECTED")
                        .font(.pixel(10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                
                Button {
                    showingSaveAllConfirm = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.pixel(13, weight: .bold))
                        .foregroundStyle(Theme.steel)
                }
                .confirmationDialog("Save All Frames", isPresented: $showingSaveAllConfirm) {
                    Button("Save \(viewModel.cutFrames.count) Frames to Photos") {
                        for (_, img) in viewModel.cutFrames {
                            UIImageWriteToSavedPhotosAlbum(UIImage(cgImage: img), nil, nil, nil)
                        }
                    }
                }
                
                Button {
                    if viewModel.selectedFrameIndices.count == viewModel.cutFrames.count {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                } label: {
                    Text(viewModel.selectedFrameIndices.count == viewModel.cutFrames.count ? "Deselect" : "Select All")
                        .font(.pixel(10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Text("Tap frames to select, then create clips")
                .font(.pixel(9, weight: .medium))
                .foregroundStyle(Theme.onDarkDim)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.cutFrames.enumerated()), id: \.offset) { index, pair in
                        frameThumb(index: index, image: pair.1)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 130)
        .background(Theme.panel)
        .overlay(alignment: .top) { Rectangle().fill(Theme.steelDark).frame(height: 1) }
    }
    
    private func frameThumb(index: Int, image: CGImage) -> some View {
        let isSelected = viewModel.selectedFrameIndices.contains(index)
        let tagColor = viewModel.clipColor(for: index)
        
        return VStack(spacing: 2) {
            // Color tag bar for the owning clip.
            if let tagColor {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tagColor)
                    .frame(height: 4)
            }
            
            Image(decorative: image, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .background(CheckerboardView())
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.steelDark,
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.white, Theme.accent)
                            .offset(x: 4, y: -4)
                    }
                }
            
            Text("\(index)")
                .font(.pixel(10, weight: .bold))
                .foregroundStyle(isSelected ? Theme.accent : Theme.onDarkDim)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.toggleFrameSelection(index)
            }
        }
        .contextMenu {
            Button {
                UIImageWriteToSavedPhotosAlbum(UIImage(cgImage: image), nil, nil, nil)
                savedFrameIndex = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if savedFrameIndex == index { savedFrameIndex = nil }
                }
            } label: {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
            }
            
            ShareLink(item: Image(decorative: image, scale: 1.0), preview: SharePreview("Frame \(index)", image: Image(decorative: image, scale: 1.0))) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .overlay {
            if savedFrameIndex == index {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, .green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Animation Clips
    
    private var clipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ANIMATION CLIPS")
                .font(.pixel(11, weight: .heavy))
                .foregroundStyle(Theme.onDark)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.clips) { clip in
                        clipCard(clip)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 100)
        .background(Theme.panelLight)
        .overlay(alignment: .top) { Rectangle().fill(Theme.steelDark).frame(height: 1) }
    }
    
    private func clipCard(_ clip: AnimationClip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(clip.colorTag.color)
                    .frame(width: 8, height: 8)
                Text(clip.name)
                    .font(.pixel(12, weight: .heavy))
                    .foregroundStyle(Theme.onDark)
                    .lineLimit(1)
            }
            
            Text("\(clip.frameCount) FRAMES")
                .font(.pixel(9, weight: .bold))
                .foregroundStyle(Theme.onDarkDim)
            
            HStack(spacing: 6) {
                Button {
                    animationVM.loadWithClips(viewModel.cutFrames, clips: viewModel.clips, activeClip: clip)
                    onSendToAnimate()
                } label: {
                    Label("Preview", systemImage: "play.fill")
                        .font(.pixel(10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.accent))
                }
                
                Button(role: .destructive) {
                    withAnimation {
                        viewModel.deleteClip(clip)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.pixel(10, weight: .bold))
                        .foregroundStyle(Theme.onDarkDim)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.steelDark))
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.steelDark, lineWidth: 1))
        )
    }
    
    // MARK: - Create Clip Sheet
    
    private var createClipSheet: some View {
        NavigationStack {
            Form {
                Section("Animation Name") {
                    TextField("e.g. Walk Cycle, Attack, Idle", text: $viewModel.newClipName)
                }
                
                Section("Color Tag") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(ClipColor.allCases, id: \.self) { color in
                            Circle()
                                .fill(color.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: viewModel.newClipColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    viewModel.newClipColor = color
                                }
                        }
                    }
                }
                
                Section {
                    Text("Frames: \(viewModel.selectedFrameIndices.sorted().map(String.init).joined(separator: ", "))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Animation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showingCreateClip = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createClipFromSelection()
                        viewModel.showingCreateClip = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $viewModel.sliceMode) {
                ForEach(SliceMode.allCases, id: \.self) { mode in
                    Text(mode == .grid ? "Grid" : "Auto-Detect").tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            if viewModel.sliceMode == .grid {
                gridControls
            } else {
                Text("Auto-detect finds non-transparent regions as frames.")
                    .font(.pixel(11, weight: .medium))
                    .foregroundStyle(Theme.onDarkDim)
            }
            
            Button {
                viewModel.sliceSheet()
            } label: {
                HStack {
                    Image(systemName: "scissors")
                    Text("SLICE SHEET")
                }
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            .opacity(viewModel.sourceImage == nil || viewModel.isProcessing ? 0.5 : 1)
            
            if !viewModel.cutFrames.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        viewModel.showingCreateClip = true
                    } label: {
                        HStack {
                            Image(systemName: "tag.fill")
                            Text("CREATE CLIP")
                        }
                    }
                    .buttonStyle(PixelButtonStyle(tint: Theme.maroon))
                    .disabled(viewModel.selectedFrameIndices.isEmpty)
                    .opacity(viewModel.selectedFrameIndices.isEmpty ? 0.5 : 1)
                    
                    Button {
                        animationVM.loadFrames(viewModel.cutFrames)
                        onSendToAnimate()
                    } label: {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                            Text("ALL → ANIMATE")
                        }
                    }
                    .buttonStyle(PixelButtonStyle(tint: Theme.steelDark))
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.pixel(11, weight: .medium))
                    .foregroundStyle(Theme.accentBright)
            }
        }
        .padding()
        .padding(.trailing, Theme.shadowOffset)
        .background(Theme.ink)
    }
    
    private var gridControls: some View {
        VStack(spacing: 8) {
            gridRow(label: "Rows", value: $viewModel.gridRows, range: 1...64, suffix: "")
            gridRow(label: "Columns", value: $viewModel.gridCols, range: 1...64, suffix: "")
            gridRow(label: "Padding", value: $viewModel.padding, range: 0...32, suffix: "px")
        }
    }
    
    private func gridRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack {
            HStack(spacing: 6) {
                Rectangle().fill(Theme.accent).frame(width: 8, height: 16)
                Text(label.uppercased())
                    .font(.pixel(12, weight: .heavy))
                    .foregroundStyle(Theme.onDark)
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.pixel(14, weight: .heavy))
                        .foregroundStyle(Theme.onDark)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.steelDark))
                }
                .disabled(value.wrappedValue <= range.lowerBound)
                
                Text("\(value.wrappedValue)\(suffix)")
                    .font(.pixel(15, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 54)
                
                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.pixel(14, weight: .heavy))
                        .foregroundStyle(Theme.onDark)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.steelDark))
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }
}

#Preview {
    SpriteSheetCutterView(animationVM: AnimationPreviewViewModel(), onSendToAnimate: {})
}
