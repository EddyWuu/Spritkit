//
//  ImagePickerView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI
import PhotosUI

// A SwiftUI wrapper around PHPickerViewController for selecting images.
struct ImagePickerView: View {
    
    @Binding var selectedImage: CGImage?
    @State private var pickerItem: PhotosPickerItem?
    
    var label: String = "Select Image"
    var systemImage: String = "photo.on.rectangle"
    
    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(label, systemImage: systemImage)
        }
        .onChange(of: pickerItem) { _, newValue in
            Task {
                await loadImage(from: newValue)
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let cgImage = uiImage.cgImage {
                await MainActor.run {
                    selectedImage = cgImage
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
}
