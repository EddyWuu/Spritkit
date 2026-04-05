//
//  ExportShareSheet.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI
import UIKit

// A share sheet button that exports processed images/data via UIActivityViewController.
struct ExportButton: View {
    
    let image: CGImage?
    var label: String = "Export"
    var systemImage: String = "square.and.arrow.up"
    
    @State private var showingShare = false
    
    var body: some View {
        Button {
            showingShare = true
        } label: {
            Label(label, systemImage: systemImage)
        }
        .disabled(image == nil)
        .sheet(isPresented: $showingShare) {
            if let image {
                ShareSheet(items: [UIImage(cgImage: image)])
            }
        }
    }
}

// UIActivityViewController wrapped for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    
    let items: [Any]
    var activities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// A menu of export format options
struct ExportMenu: View {
    
    let image: CGImage?
    let onExport: (ExportFormat) -> Void
    
    var body: some View {
        Menu {
            ForEach(ExportFormat.allCases) { format in
                Button {
                    onExport(format)
                } label: {
                    Label(format.label, systemImage: iconFor(format))
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(image == nil)
    }
    
    private func iconFor(_ format: ExportFormat) -> String {
        switch format {
        case .png: return "photo"
        case .spriteSheet: return "rectangle.split.3x3"
        case .palette: return "paintpalette"
        case .gif: return "play.rectangle"
        }
    }
}
