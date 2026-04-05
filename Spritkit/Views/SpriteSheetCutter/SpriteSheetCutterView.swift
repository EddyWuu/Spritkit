//
//  SpriteSheetCutterView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

struct SpriteSheetCutterView: View {
    
    @StateObject private var viewModel = SpriteSheetCutterViewModel()
    @ObservedObject var animationVM: AnimationPreviewViewModel
    var onSendToAnimate: () -> Void
    @State private var importedImage: CGImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasSection
                
                Divider()
                
                // Cut frames preview
                if !viewModel.cutFrames.isEmpty {
                    framesPreview
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
    
    // MARK: - Frames Preview
    
    private var framesPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.frameCount) Frames")
                .font(.caption.weight(.medium))
                .padding(.horizontal)
                .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.cutFrames.enumerated()), id: \.offset) { index, pair in
                        VStack(spacing: 2) {
                            Image(decorative: pair.1, scale: 1.0)
                                .interpolation(.none)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .background(CheckerboardView().opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.3))
                                )
                            
                            Text("\(index)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 100)
        .background(Color(uiColor: .secondarySystemBackground))
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
            
            // Send to Animate button
            if !viewModel.cutFrames.isEmpty {
                Button {
                    animationVM.loadFrames(viewModel.cutFrames)
                    onSendToAnimate()
                } label: {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                        Text("Send to Animate (\(viewModel.frameCount) frames)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
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
