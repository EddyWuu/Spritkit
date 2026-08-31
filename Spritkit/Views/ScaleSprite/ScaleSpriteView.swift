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
                controlsSection
            }
            .background(Theme.ink)
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
                        VStack(spacing: 10) {
                            ProgressView().tint(Theme.accent)
                            Text("SCALING…")
                                .font(.pixel(11, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(Theme.onDark)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .fill(Theme.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radius)
                                        .strokeBorder(Theme.steelDark, lineWidth: Theme.border)
                                )
                        )
                    }
                }
        } else {
            PixelEmptyState(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "No Sprite Loaded",
                message: "Import a sprite to scale it with nearest-neighbor interpolation."
            ) {
                ImagePickerView(
                    selectedImage: $viewModel.sourceImage,
                    label: "Select Sprite",
                    systemImage: "photo.badge.plus"
                )
                .buttonStyle(PixelButtonStyle())
                .fixedSize()
            }
        }
    }
    
    private var dimensionBadge: some View {
        PixelBadge {
            HStack(spacing: 8) {
                if viewModel.sourceImage != nil {
                    Text("IN \(viewModel.inputDimensions)")
                }
                if viewModel.outputImage != nil {
                    Text("OUT \(viewModel.outputDimensions)")
                        .foregroundStyle(Theme.accent)
                } else if viewModel.sourceImage != nil {
                    Text("→ \(viewModel.previewDimensions)")
                        .foregroundStyle(Theme.accent)
                }
            }
            .font(.pixel(11, weight: .bold))
            .foregroundStyle(Theme.onDark)
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 14) {
            Toggle("Custom Dimensions", isOn: $viewModel.useCustomDimensions)
                .font(.pixel(13, weight: .bold))
                .foregroundStyle(Theme.onDark)
                .tint(Theme.accent)
            
            if viewModel.useCustomDimensions {
                customDimensionsControls
            } else {
                scaleFactorControls
            }
            
            Button {
                viewModel.scale()
            } label: {
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("SCALE")
                }
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            .opacity(viewModel.sourceImage == nil || viewModel.isProcessing ? 0.5 : 1)
            
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
    
    private var scaleFactorControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PixelSectionHeader(title: "Scale Factor")
                Text("\(viewModel.scaleFactor, specifier: "%.1f")×")
                    .font(.pixel(13, weight: .heavy))
                    .foregroundStyle(Theme.accent)
            }
            
            Slider(value: $viewModel.scaleFactor, in: 0.25...16, step: 0.25)
                .tint(Theme.accent)
            
            HStack(spacing: 8) {
                ForEach([0.5, 1.0, 2.0, 4.0, 8.0], id: \.self) { preset in
                    Button("\(preset, specifier: "%.0g")×") {
                        viewModel.scaleFactor = preset
                    }
                    .buttonStyle(PixelSecondaryButtonStyle())
                }
            }
        }
    }
    
    private var customDimensionsControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Lock Aspect Ratio", isOn: $viewModel.lockAspectRatio)
                .font(.pixel(12, weight: .bold))
                .foregroundStyle(Theme.onDarkDim)
                .tint(Theme.accent)
            
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WIDTH").font(.pixel(10, weight: .bold)).foregroundStyle(Theme.onDarkDim)
                    TextField("W", value: $viewModel.customWidth, format: .number)
                        .textFieldStyle(.plain)
                        .font(.pixel(15, weight: .bold))
                        .foregroundStyle(Theme.onDark)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .fill(Theme.panel)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                                    .strokeBorder(Theme.steelDark, lineWidth: Theme.border))
                        )
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.customWidth) { _, newVal in
                            if viewModel.lockAspectRatio {
                                viewModel.updateCustomWidth(newVal)
                            }
                        }
                }
                
                Image(systemName: viewModel.lockAspectRatio ? "lock.fill" : "lock.open")
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEIGHT").font(.pixel(10, weight: .bold)).foregroundStyle(Theme.onDarkDim)
                    TextField("H", value: $viewModel.customHeight, format: .number)
                        .textFieldStyle(.plain)
                        .font(.pixel(15, weight: .bold))
                        .foregroundStyle(Theme.onDark)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .fill(Theme.panel)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                                    .strokeBorder(Theme.steelDark, lineWidth: Theme.border))
                        )
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
