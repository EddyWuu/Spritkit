//
//  ScaleSpriteView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

struct ScaleSpriteView: View {
    
    @StateObject private var viewModel = ScaleSpriteViewModel()
    @State private var showingHelp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasSection
                Divider()
                controlsSection
            }
            .navigationTitle("Scale Sprite")
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
                HelpSheetView.scaleSprite
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: viewModel.sourceImage) { _, newImage in
                viewModel.outputImage = nil
                if let img = newImage {
                    viewModel.customWidth = img.width
                    viewModel.customHeight = img.height
                }
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
                    dimensionBadge.padding(8)
                }
                .overlay {
                    if viewModel.isProcessing {
                        ProgressView("Scaling…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
        } else {
            ContentUnavailableView {
                Label("No Image Selected", systemImage: "arrow.up.left.and.arrow.down.right")
            } description: {
                Text("Import a sprite to scale it with nearest-neighbor interpolation.")
            } actions: {
                ImagePickerView(
                    selectedImage: $viewModel.sourceImage,
                    label: "Select Sprite",
                    systemImage: "photo.badge.plus"
                )
                .buttonStyle(.borderedProminent)
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    private var dimensionBadge: some View {
        HStack(spacing: 8) {
            if viewModel.sourceImage != nil {
                Text("In: \(viewModel.inputDimensions)")
            }
            if viewModel.outputImage != nil {
                Text("Out: \(viewModel.outputDimensions)")
            } else if viewModel.sourceImage != nil {
                Text("→ \(viewModel.previewDimensions)")
                    .foregroundStyle(.secondary)
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
            // Mode toggle
            Toggle("Custom Dimensions", isOn: $viewModel.useCustomDimensions)
                .font(.subheadline)
            
            if viewModel.useCustomDimensions {
                customDimensionsControls
            } else {
                scaleFactorControls
            }
            
            // Scale button
            Button {
                viewModel.scale()
            } label: {
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Scale")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    private var scaleFactorControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Scale Factor")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(viewModel.scaleFactor, specifier: "%.1f")×")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: $viewModel.scaleFactor, in: 0.25...16, step: 0.25) {
                Text("Scale")
            } minimumValueLabel: {
                Text("¼").font(.caption2)
            } maximumValueLabel: {
                Text("16").font(.caption2)
            }
            
            // Quick presets
            HStack {
                ForEach([0.5, 1.0, 2.0, 4.0, 8.0], id: \.self) { preset in
                    Button("\(preset, specifier: "%.0g")×") {
                        viewModel.scaleFactor = preset
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }
    
    private var customDimensionsControls: some View {
        VStack(spacing: 8) {
            Toggle("Lock Aspect Ratio", isOn: $viewModel.lockAspectRatio)
                .font(.caption)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Width").font(.caption)
                    TextField("W", value: $viewModel.customWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.customWidth) { _, newVal in
                            if viewModel.lockAspectRatio {
                                viewModel.updateCustomWidth(newVal)
                            }
                        }
                }
                
                Image(systemName: viewModel.lockAspectRatio ? "lock.fill" : "lock.open")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    Text("Height").font(.caption)
                    TextField("H", value: $viewModel.customHeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.customHeight) { _, newVal in
                            if viewModel.lockAspectRatio {
                                viewModel.updateCustomHeight(newVal)
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    ScaleSpriteView()
}
