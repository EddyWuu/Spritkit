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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasSection
                
                Divider()
                
                // Cut frames strip with selection
                if !viewModel.cutFrames.isEmpty {
                    framesStrip
                    Divider()
                }
                
                // Animation clips list
                if !viewModel.clips.isEmpty {
                    clipsSection
                    Divider()
                }
                
                controlsSection
            }
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
                    ImagePickerView(
                        selectedImage: $importedImage,
                        label: "Import",
                        systemImage: "photo.badge.plus"
                    )
                }
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
                HStack(spacing: 8) {
                    Text(viewModel.inputDimensions)
                    if viewModel.sliceMode == .grid {
                        Text("Frame: \(viewModel.frameDimensions)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
            }
            .overlay {
                if viewModel.isProcessing {
                    ProgressView("Slicing…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Sprite Sheet", systemImage: "rectangle.split.3x3")
            } description: {
                Text("Import a sprite sheet to slice it into individual frames.")
            } actions: {
                ImagePickerView(
                    selectedImage: $importedImage,
                    label: "Select Sheet",
                    systemImage: "photo.badge.plus"
                )
                .buttonStyle(.borderedProminent)
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    // MARK: - Frames Strip (selectable)
    
    private var framesStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with frame count and selection controls
            HStack {
                Text("\(viewModel.frameCount) Frames")
                    .font(.caption.weight(.medium))
                
                Spacer()
                
                if !viewModel.selectedFrameIndices.isEmpty {
                    Text("\(viewModel.selectedFrameIndices.count) selected")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                
                Button {
                    showingSaveAllConfirm = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.caption)
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
                    Text(viewModel.selectedFrameIndices.count == viewModel.cutFrames.count ? "Deselect All" : "Select All")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Hint text
            Text("Tap frames to select, then create animation clips")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            // Scrollable frame strip
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
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private func frameThumb(index: Int, image: CGImage) -> some View {
        let isSelected = viewModel.selectedFrameIndices.contains(index)
        let tagColor = viewModel.clipColor(for: index)
        
        return VStack(spacing: 2) {
            // Color tag bar (shows which clip this frame belongs to)
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
                .background(CheckerboardView().opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.white, Color.accentColor)
                            .offset(x: 4, y: -4)
                    }
                }
            
            Text("\(index)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
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
            Text("Animation Clips")
                .font(.caption.weight(.medium))
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
        .frame(height: 90)
        .background(Color(uiColor: .tertiarySystemBackground))
    }
    
    private func clipCard(_ clip: AnimationClip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(clip.colorTag.color)
                    .frame(width: 8, height: 8)
                Text(clip.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            
            Text("\(clip.frameCount) frames")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                // Preview this clip
                Button {
                    animationVM.loadWithClips(viewModel.cutFrames, clips: viewModel.clips, activeClip: clip)
                    onSendToAnimate()
                } label: {
                    Label("Preview", systemImage: "play.fill")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                
                // Delete clip
                Button(role: .destructive) {
                    withAnimation {
                        viewModel.deleteClip(clip)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(8)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
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
            // Slice mode picker
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Slice button
            Button {
                viewModel.sliceSheet()
            } label: {
                HStack {
                    Image(systemName: "scissors")
                    Text("Slice Sheet")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            
            // Action buttons after slicing
            if !viewModel.cutFrames.isEmpty {
                HStack(spacing: 12) {
                    // Create animation clip from selection
                    Button {
                        viewModel.showingCreateClip = true
                    } label: {
                        HStack {
                            Image(systemName: "tag.fill")
                            Text("Create Clip")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(viewModel.selectedFrameIndices.isEmpty)
                    
                    // Quick send all frames to animate
                    Button {
                        animationVM.loadFrames(viewModel.cutFrames)
                        onSendToAnimate()
                    } label: {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                            Text("All → Animate")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
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
            Text(label)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .disabled(value.wrappedValue <= range.lowerBound)
                
                Text("\(value.wrappedValue)\(suffix)")
                    .font(.subheadline.monospaced().weight(.medium))
                    .frame(width: 50)
                
                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }
}

#Preview {
    SpriteSheetCutterView(animationVM: AnimationPreviewViewModel(), onSendToAnimate: {})
}
