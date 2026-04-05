//
//  ExtractPaletteView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

struct ExtractPaletteView: View {
    
    @StateObject private var viewModel = ExtractPaletteViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image preview (compact)
                imageSection
                
                Divider()
                
                // Palette grid
                if let palette = viewModel.palette {
                    paletteGrid(palette)
                }
                
                Divider()
                
                // Controls
                controlsSection
            }
            .navigationTitle("Extract Palette")
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
                    ImagePickerView(
                        selectedImage: $viewModel.sourceImage,
                        label: "Import",
                        systemImage: "photo.badge.plus"
                    )
                }
            }
            .onChange(of: viewModel.sourceImage) { _, _ in
                viewModel.palette = nil
            }
        }
    }
    
    // MARK: - Image Section
    
    @ViewBuilder
    private var imageSection: some View {
        if let image = viewModel.sourceImage {
            SpriteCanvasView(image: image)
                .frame(height: 200)
                .overlay(alignment: .topLeading) {
                    Text(viewModel.inputDimensions)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
                .overlay {
                    if viewModel.isProcessing {
                        ProgressView("Extracting…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
        } else {
            ContentUnavailableView {
                Label("No Image Selected", systemImage: "paintpalette")
            } description: {
                Text("Import an image to extract its color palette.")
            } actions: {
                ImagePickerView(
                    selectedImage: $viewModel.sourceImage,
                    label: "Select Image",
                    systemImage: "photo.badge.plus"
                )
                .buttonStyle(.borderedProminent)
            }
            .frame(height: 200)
        }
    }
    
    // MARK: - Palette Grid
    
    private func paletteGrid(_ palette: Palette) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(palette.colors) { color in
                    colorSwatch(color)
                }
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
    }
    
    private func colorSwatch(_ color: PaletteColor) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .overlay {
                    if viewModel.selectedColor?.id == color.id {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                }
            
            Text(color.hex)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if viewModel.selectedColor?.id == color.id {
                    viewModel.selectedColor = nil
                } else {
                    viewModel.selectedColor = color
                    UIPasteboard.general.string = color.hex
                }
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Max colors picker
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Max Colors")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(viewModel.maxColors)")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    ForEach(ExtractPaletteViewModel.colorPresets, id: \.self) { preset in
                        Button("\(preset)") {
                            viewModel.maxColors = preset
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.maxColors == preset ? .accentColor : .secondary)
                        .font(.caption)
                    }
                }
            }
            
            // Extract button
            Button {
                viewModel.extractPalette()
            } label: {
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Extract Palette")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            
            // Selected color info
            if let selected = viewModel.selectedColor {
                HStack {
                    Circle()
                        .fill(selected.color)
                        .frame(width: 20, height: 20)
                    Text(selected.hex)
                        .font(.caption.monospaced())
                    Text("• \(selected.frequency) pixels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Copied!")
                        .font(.caption)
                        .foregroundStyle(.green)
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
}

#Preview {
    ExtractPaletteView()
}
