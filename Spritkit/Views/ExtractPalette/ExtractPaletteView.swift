//
//  ExtractPaletteView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

enum PaletteViewMode: String, CaseIterable {
    case swatches = "Swatches"
    case hex = "Hex"
}

struct ExtractPaletteView: View {
    
    @StateObject private var viewModel = ExtractPaletteViewModel()
    @State private var showingHelp = false
    @State private var viewMode: PaletteViewMode = .swatches
    @State private var copiedAll = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                imageSection
                
                if let palette = viewModel.palette {
                    Picker("View", selection: $viewMode) {
                        ForEach(PaletteViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    switch viewMode {
                    case .swatches:
                        paletteGrid(palette)
                    case .hex:
                        hexList(palette)
                    }
                }
                
                controlsSection
            }
            .background(Theme.ink)
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
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    
                    ImagePickerView(
                        selectedImage: $viewModel.sourceImage,
                        label: "Import",
                        systemImage: "photo.badge.plus"
                    )
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpSheetView.extractPalette
                    .presentationDetents([.medium, .large])
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
                    PixelBadge {
                        Text(viewModel.inputDimensions)
                            .font(.pixel(11, weight: .bold))
                            .foregroundStyle(Theme.onDark)
                    }
                    .padding(8)
                }
                .overlay {
                    if viewModel.isProcessing {
                        VStack(spacing: 10) {
                            ProgressView().tint(Theme.accent)
                            Text("EXTRACTING…")
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
                icon: "paintpalette",
                title: "No Image Loaded",
                message: "Import an image to extract its color palette."
            ) {
                ImagePickerView(
                    selectedImage: $viewModel.sourceImage,
                    label: "Select Image",
                    systemImage: "photo.badge.plus"
                )
                .buttonStyle(PixelButtonStyle())
                .fixedSize()
            }
            .frame(height: 260)
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
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(color.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(Theme.steelDark, lineWidth: 1)
                )
                .overlay {
                    if viewModel.selectedColor?.id == color.id {
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .strokeBorder(Theme.accent, lineWidth: 3)
                    }
                }
            
            Text(color.hex)
                .font(.pixel(10, weight: .bold))
                .foregroundStyle(Theme.onDark)
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
    
    // MARK: - Hex List
    
    private func hexList(_ palette: Palette) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(palette.colorCount) COLORS")
                    .font(.pixel(11, weight: .bold))
                    .foregroundStyle(Theme.onDarkDim)
                Spacer()
                Button {
                    UIPasteboard.general.string = palette.hexColors.joined(separator: "\n")
                    withAnimation { copiedAll = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copiedAll = false }
                    }
                } label: {
                    Label(copiedAll ? "Copied!" : "Copy All", systemImage: copiedAll ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(PixelSecondaryButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(palette.colors) { color in
                        let selected = viewModel.selectedColor?.id == color.id
                        HStack {
                            Text(color.hex)
                                .font(.pixel(15, weight: .bold))
                                .foregroundStyle(Theme.onDark)
                            Spacer()
                            Image(systemName: selected ? "checkmark" : "doc.on.doc")
                                .font(.pixel(12, weight: .bold))
                                .foregroundStyle(selected ? Theme.accent : Theme.steel)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .fill(Theme.panel)
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                                    .strokeBorder(selected ? Theme.accent : Theme.steelDark, lineWidth: selected ? 2 : 1))
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIPasteboard.general.string = color.hex
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.selectedColor = color
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PixelSectionHeader(title: "Max Colors")
                    Text("\(viewModel.maxColors)")
                        .font(.pixel(13, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
                
                HStack(spacing: 8) {
                    ForEach(ExtractPaletteViewModel.colorPresets, id: \.self) { preset in
                        let active = viewModel.maxColors == preset
                        Button("\(preset)") {
                            viewModel.maxColors = preset
                        }
                        .buttonStyle(PixelSecondaryButtonStyle())
                        .overlay(
                            active
                            ? RoundedRectangle(cornerRadius: Theme.radius)
                                .strokeBorder(Theme.accent, lineWidth: 2)
                            : nil
                        )
                    }
                }
            }
            
            Button {
                viewModel.extractPalette()
            } label: {
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("EXTRACT PALETTE")
                }
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(viewModel.sourceImage == nil || viewModel.isProcessing)
            .opacity(viewModel.sourceImage == nil || viewModel.isProcessing ? 0.5 : 1)
            
            if let selected = viewModel.selectedColor {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(selected.color)
                        .frame(width: 20, height: 20)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.steelDark, lineWidth: 1))
                    Text(selected.hex)
                        .font(.pixel(12, weight: .bold))
                        .foregroundStyle(Theme.onDark)
                    Text("\(selected.frequency) px")
                        .font(.pixel(11, weight: .medium))
                        .foregroundStyle(Theme.onDarkDim)
                    Spacer()
                    Text("COPIED!")
                        .font(.pixel(11, weight: .heavy))
                        .foregroundStyle(Theme.accent)
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
}

#Preview {
    ExtractPaletteView()
}
