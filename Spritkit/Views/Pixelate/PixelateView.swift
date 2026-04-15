//
//  PixelateView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

struct PixelateView: View {
    
    @StateObject private var viewModel = PixelateViewModel()
    @State private var showingHelp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Canvas area
                canvasSection
                
                Divider()
                
                // Controls
                controlsSection
            }
            .navigationTitle("Pixelate")
            .toolbar {
                if viewModel.sourceImage != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) {
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
                    
                    ExportButton(image: viewModel.outputImage)
                    
                    ImagePickerView(
                        selectedImage: $viewModel.sourceImage,
                        label: "Import",
                        systemImage: "photo.badge.plus"
                    )
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpSheetView.pixelate
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: viewModel.sourceImage) { _, _ in
                viewModel.outputImage = nil
            }
        }
    }
    
    // MARK: - Canvas
    
    @ViewBuilder
    private var canvasSection: some View {
        if let displayImage = viewModel.outputImage ?? viewModel.sourceImage {
            SpriteCanvasView(image: displayImage)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    dimensionBadge
                        .padding(8)
                }
                .overlay {
                    if viewModel.isProcessing {
                        ProgressView("Processing…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
        } else {
            emptyState
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Image Selected", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Import a photo to pixelate it into pixel art.")
        } actions: {
            ImagePickerView(
                selectedImage: $viewModel.sourceImage,
                label: "Select Photo",
                systemImage: "photo.badge.plus"
            )
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var dimensionBadge: some View {
        HStack(spacing: 8) {
            if viewModel.sourceImage != nil {
                Text("In: \(viewModel.inputDimensions)")
            }
            if viewModel.outputImage != nil {
                Text("Out: \(viewModel.outputDimensions)")
            }
        }
        .font(.caption.monospaced())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Block size slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Block Size")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(viewModel.blockSize))px")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $viewModel.blockSize, in: 2...64, step: 1) {
                    Text("Block Size")
                } minimumValueLabel: {
                    Text("2").font(.caption2)
                } maximumValueLabel: {
                    Text("64").font(.caption2)
                }
            }
            
            // Apply button
            Button {
                viewModel.pixelate()
            } label: {
                HStack {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                    Text("Pixelate")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    PixelateView()
}
