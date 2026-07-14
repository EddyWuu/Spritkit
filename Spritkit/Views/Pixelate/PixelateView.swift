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
            .onChange(of: viewModel.sourceImage) { _, _ in
                viewModel.outputImage = nil
                showingOriginal = false
            }
        }
    }
    
    // MARK: - Canvas
    
    @ViewBuilder
    private var canvasSection: some View {
        if let source = viewModel.sourceImage {
            let displayed = (showingOriginal ? source : (viewModel.outputImage ?? source))
            SpriteCanvasView(image: displayed)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    dimensionBadge
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    // Simple toggle to compare against the original (only once processed)
                    if viewModel.outputImage != nil {
                        Button {
                            showingOriginal.toggle()
                        } label: {
                            Label(showingOriginal ? "Original" : "Result",
                                  systemImage: showingOriginal ? "photo" : "wand.and.stars")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .padding(8)
                    }
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
                    // Clear the stale result so the user re-applies with the new size
                    viewModel.outputImage = nil
                    showingOriginal = false
                }
            }
            
            // Apply button
            Button {
                showingOriginal = false
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
            List {
                ForEach(PixelationMethod.allCases) { method in
                    Button {
                        viewModel.selectedMethod = method
                        showingMethodPicker = false
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: method.icon)
                                .font(.title3)
                                .frame(width: 32)
                                .foregroundStyle(viewModel.selectedMethod == method ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(method.displayName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(method.shortDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if viewModel.selectedMethod == method {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
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
}

#Preview {
    PixelateView()
}
