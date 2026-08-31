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
                canvasSection
                
                controlsSection
            }
            .background(Theme.ink)
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
                    // Compare against the original once processed.
                    if viewModel.outputImage != nil {
                        Button {
                            showingOriginal.toggle()
                        } label: {
                            Label(showingOriginal ? "Original" : "Result",
                                  systemImage: showingOriginal ? "photo" : "wand.and.stars")
                                .font(.pixel(11, weight: .bold))
                                .foregroundStyle(Theme.onDark)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.radius)
                                        .fill(Theme.panel.opacity(0.92))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.radius)
                                                .strokeBorder(Theme.steelDark, lineWidth: 1)
                                        )
                                )
                        }
                        .padding(8)
                    }
                }
                .overlay {
                    if viewModel.isProcessing {
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(Theme.accent)
                            Text("PROCESSING…")
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
            emptyState
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .strokeBorder(Theme.steelDark, lineWidth: Theme.border)
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.steel)
            }
            .pixelShadow()
            
            VStack(spacing: 6) {
                Text("NO IMAGE LOADED")
                    .font(.pixel(16, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.onDark)
                Text("Import a photo to pixelate it into pixel art.")
                    .font(.pixel(12, weight: .medium))
                    .foregroundStyle(Theme.onDarkDim)
                    .multilineTextAlignment(.center)
            }
            
            ImagePickerView(
                selectedImage: $viewModel.sourceImage,
                label: "Select Photo",
                systemImage: "photo.badge.plus"
            )
            .buttonStyle(PixelButtonStyle())
            .fixedSize()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink)
    }
    
    private var dimensionBadge: some View {
        HStack(spacing: 8) {
            if viewModel.sourceImage != nil {
                Text("IN \(viewModel.inputDimensions)")
            }
            if viewModel.outputImage != nil {
                Text("OUT \(viewModel.outputDimensions)")
                    .foregroundStyle(Theme.accent)
            }
        }
        .font(.pixel(11, weight: .bold))
        .foregroundStyle(Theme.onDark)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.panel.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(Theme.steelDark, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 14) {
            Button {
                showingMethodPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.selectedMethod.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedMethod.displayName)
                            .font(.pixel(14, weight: .heavy))
                            .foregroundStyle(Theme.onDark)
                        Text(viewModel.selectedMethod.shortDescription)
                            .font(.pixel(10, weight: .medium))
                            .foregroundStyle(Theme.onDarkDim)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.pixel(11, weight: .bold))
                        .foregroundStyle(Theme.steel)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(Theme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(Theme.steelDark, lineWidth: Theme.border)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.sourceImage == nil)
            
            sliderRow(
                title: "Block Size",
                value: "\(Int(viewModel.blockSize))px",
                binding: Binding(
                    get: { Double(viewModel.blockSize) },
                    set: { viewModel.blockSize = CGFloat($0) }
                ),
                range: 2...64
            )
            .onChange(of: viewModel.blockSize) { _, _ in
                viewModel.outputImage = nil
                showingOriginal = false
            }
            
            // Palette size — palette-based methods only.
            if viewModel.selectedMethod.usesPalette {
                sliderRow(
                    title: "Colors",
                    value: "\(viewModel.colorCount)",
                    binding: Binding(
                        get: { Double(viewModel.colorCount) },
                        set: { viewModel.colorCount = Int($0) }
                    ),
                    range: 2...64
                )
                .onChange(of: viewModel.colorCount) { _, _ in
                    viewModel.outputImage = nil
                    showingOriginal = false
                }
            }
            
            Button {
                showingOriginal = false
                viewModel.pixelate()
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedMethod.icon)
                    Text("APPLY \(viewModel.selectedMethod.displayName.uppercased())")
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
        .padding(.trailing, Theme.shadowOffset)  // room for button shadow
        .background(Theme.ink)
    }
    
    // A themed slider with a pixel label header.
    private func sliderRow(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PixelSectionHeader(title: title)
                Text(value)
                    .font(.pixel(13, weight: .heavy))
                    .foregroundStyle(Theme.accent)
            }
            Slider(value: binding, in: range, step: 1)
                .tint(Theme.accent)
        }
    }
    
    // MARK: - Method Picker Sheet
    
    private var methodPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(PixelationMethod.allCases) { method in
                        let selected = viewModel.selectedMethod == method
                        Button {
                            viewModel.selectedMethod = method
                            showingMethodPicker = false
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: method.icon)
                                    .font(.system(size: 20))
                                    .frame(width: 34)
                                    .foregroundStyle(selected ? .white : Theme.steel)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(method.displayName)
                                        .font(.pixel(14, weight: .heavy))
                                        .foregroundStyle(selected ? .white : Theme.onDark)
                                    Text(method.shortDescription)
                                        .font(.pixel(10, weight: .medium))
                                        .foregroundStyle(selected ? Color.white.opacity(0.8) : Theme.onDarkDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.pixel(14, weight: .heavy))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radius)
                                    .fill(selected ? Theme.accent : Theme.panel)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radius)
                                    .strokeBorder(selected ? Color.black.opacity(0.3) : Theme.steelDark,
                                                  lineWidth: Theme.border)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Theme.ink)
            .navigationTitle("Pixelation Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingMethodPicker = false
                    }
                    .font(.pixel(14, weight: .heavy))
                }
            }
        }
    }
}

#Preview {
    PixelateView()
}
