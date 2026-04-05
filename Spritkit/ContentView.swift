//
//  ContentView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

// MARK: - Operation Tab Definition

// All available sprite operations. Add new tools here — they auto-appear in the tab bar.
enum OperationTab: Int, CaseIterable, Identifiable {
    
    // Current tools
    case pixelate = 0
    case scaleSprite = 1
    case extractPalette = 2
    case sheetCutter = 3
    case animationPreview = 4
    
    // Future tools — assign next Int values
    // case colorReplace = 5
    // case flipRotate = 6
    // case outline = 7
    // case ditherize = 8
    // case tileMap = 9
    // case spriteCompose = 10
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .pixelate: return "Pixelate"
        case .scaleSprite: return "Scale"
        case .extractPalette: return "Palette"
        case .sheetCutter: return "Cutter"
        case .animationPreview: return "Animate"
        }
    }
    
    var icon: String {
        switch self {
        case .pixelate: return "square.grid.3x3.topleft.filled"
        case .scaleSprite: return "arrow.up.left.and.arrow.down.right"
        case .extractPalette: return "paintpalette"
        case .sheetCutter: return "scissors"
        case .animationPreview: return "play.rectangle"
        }
    }
}

// MARK: - Content View (matches Spritfill tab pattern)

struct ContentView: View {
    
    @State private var selectedTab: Int = 0
    @StateObject private var animationVM = AnimationPreviewViewModel()
    
    var body: some View {
        
        TabView(selection: $selectedTab) {
            
            PixelateView()
                .tag(OperationTab.pixelate.rawValue)
                .tabItem {
                    Label(OperationTab.pixelate.label, systemImage: OperationTab.pixelate.icon)
                }
            
            LazyTab { ScaleSpriteView() }
                .tag(OperationTab.scaleSprite.rawValue)
                .tabItem {
                    Label(OperationTab.scaleSprite.label, systemImage: OperationTab.scaleSprite.icon)
                }
            
            LazyTab { ExtractPaletteView() }
                .tag(OperationTab.extractPalette.rawValue)
                .tabItem {
                    Label(OperationTab.extractPalette.label, systemImage: OperationTab.extractPalette.icon)
                }
            
            LazyTab {
                SpriteSheetCutterView(animationVM: animationVM) {
                    selectedTab = OperationTab.animationPreview.rawValue
                }
            }
                .tag(OperationTab.sheetCutter.rawValue)
                .tabItem {
                    Label(OperationTab.sheetCutter.label, systemImage: OperationTab.sheetCutter.icon)
                }
            
            LazyTab { AnimationPreviewView(viewModel: animationVM) }
                .tag(OperationTab.animationPreview.rawValue)
                .tabItem {
                    Label(OperationTab.animationPreview.label, systemImage: OperationTab.animationPreview.icon)
                }
        }
    }
}

// MARK: - Lazy Tab (matches Spritfill pattern)

// Defers creation of a heavy tab view until it first appears.
// After first load, the view stays alive (not re-created on every tab switch).
private struct LazyTab<Content: View>: View {
    let build: () -> Content
    @State private var hasAppeared = false
    
    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: some View {
        if hasAppeared {
            build()
        } else {
            Color.clear
                .onAppear { hasAppeared = true }
        }
    }
}

#Preview {
    ContentView()
}
