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
    @State private var showingMethodPicker = false
    @State private var showingOriginal = false
    
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
            .sheet(isPresented: $showingMethodPicker) {
                methodPickerSheet
                    .presentationDetents([.large])
            }
            .onChange(of: viewModel.sourceImage) { _, newImage in
                viewModel.outputImage = nil
                if newImage != nil {
                    viewModel.generatePreviews()
                }
            }
        }
    }
    
    // MARK: - Canvas
    
    @ViewBuilder
    private var canvasSection: some View {
        if let source = viewModel.sourceImage {
            if let output = viewModel.outputImage {
                // Show an interactive before/after split for better comparison
                BeforeAfterView(original: source, processed: output)
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
                // Only source available
                SpriteCanvasView(image: source)
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
            // Method selector button
            Button {
                showingMethodPicker = true
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedMethod.icon)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedMethod.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.selectedMethod.shortDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.sourceImage == nil)
            
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
                .onChange(of: viewModel.blockSize) { _, _ in
                    // Debounce: regenerate previews after slider settles
                    viewModel.outputImage = nil
                    viewModel.generatePreviews()
                }
            }
            
            // Apply button
            Button {
                viewModel.pixelate()
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedMethod.icon)
                    Text("Apply \(viewModel.selectedMethod.displayName)")
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
    
    // MARK: - Method Picker Sheet
    
    private var methodPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 14) {
                    ForEach(PixelationMethod.allCases) { method in
                        methodCard(method)
                    }
                }
                .padding()
            }
            .navigationTitle("Pixelation Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingMethodPicker = false
                    }
                }
            }
        }
    }
    
    private func methodCard(_ method: PixelationMethod) -> some View {
        let isSelected = viewModel.selectedMethod == method
        return Button {
            viewModel.selectedMethod = method
            showingMethodPicker = false
        } label: {
            VStack(spacing: 8) {
                GeometryReader { geo in
                    // Use square thumbnail boxes so very wide images don't shrink the preview height.
                    let cardWidth = geo.size.width
                    let spacing: CGFloat = 6
                    let boxWidth = (cardWidth - spacing) / 2
                    let boxSize = min(boxWidth, 120)

                    HStack(spacing: spacing) {
                        // Before
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(uiColor: .tertiarySystemBackground))
                            if let source = viewModel.sourceImage {
                                Image(decorative: source, scale: 1.0)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: boxSize, height: boxSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: method.icon)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Spacer()
                                Text("Before")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .padding(6)
                            }
                        }
                        .frame(width: boxSize, height: boxSize)

                        // After
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(uiColor: .tertiarySystemBackground))
                            if let preview = viewModel.previews[method] {
                                Image(decorative: preview, scale: 1.0)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: boxSize, height: boxSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else if viewModel.isGeneratingPreviews {
                                ProgressView()
                            } else {
                                Image(systemName: method.icon)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Spacer()
                                Text("After")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .padding(6)
                            }
                        }
                        .frame(width: boxSize, height: boxSize)
                    }
                    .frame(height: boxSize)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 140)

                // Label
                VStack(spacing: 2) {
                    Text(method.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(method.shortDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 6)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PixelateView()
}
