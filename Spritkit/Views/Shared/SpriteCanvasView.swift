//
//  SpriteCanvasView.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI

// A zoomable, pannable image preview for sprites and pixel art.
// Uses nearest-neighbor interpolation to keep pixels crisp at all zoom levels.
struct SpriteCanvasView: View {
    
    let image: CGImage
    var showGrid: Bool = false
    var gridRows: Int = 1
    var gridCols: Int = 1
    var gridColor: Color = .yellow.opacity(0.7)
    
    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            let imageSize = CGSize(width: image.width, height: image.height)
            let fitScale = fitScaleFor(imageSize: imageSize, in: geo.size)
            
            ZStack {
                // Checkerboard background (transparency indicator)
                CheckerboardView()
                    .opacity(0.3)
                
                // The sprite image — nearest-neighbor interpolation
                Image(decorative: image, scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        if showGrid {
                            GridOverlayView(rows: gridRows, cols: gridCols, color: gridColor)
                        }
                    }
            }
            .scaleEffect(zoom * fitScale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        zoom = max(0.5, min(value.magnification, 32))
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) {
                    zoom = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
        .clipped()
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func fitScaleFor(imageSize: CGSize, in containerSize: CGSize) -> CGFloat {
        let scaleX = containerSize.width / imageSize.width
        let scaleY = containerSize.height / imageSize.height
        return min(scaleX, scaleY)
    }
}

// MARK: - Checkerboard Background

// A checkerboard pattern commonly used to indicate transparency
struct CheckerboardView: View {
    var squareSize: CGFloat = 10
    var color1: Color = Color(white: 0.85)
    var color2: Color = Color(white: 0.95)
    
    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(isLight ? color1 : color2))
                }
            }
        }
    }
}

// MARK: - Grid Overlay

// Draws a grid overlay on the sprite canvas (for sprite sheet cutting)
struct GridOverlayView: View {
    var rows: Int
    var cols: Int
    var color: Color = .yellow.opacity(0.7)
    
    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(cols)
            let cellHeight = size.height / CGFloat(rows)
            
            // Vertical lines
            for col in 1..<cols {
                let x = CGFloat(col) * cellWidth
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
            
            // Horizontal lines
            for row in 1..<rows {
                let y = CGFloat(row) * cellHeight
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
    }
}
