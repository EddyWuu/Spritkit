import SwiftUI

// A simple before/after comparison view that shows original and processed images
// with a draggable divider. Keeps both images centered and uses aspect-fit scaling
// so long horizontal/vertical images don't distort layout.
struct BeforeAfterView: View {
    let original: CGImage
    let processed: CGImage
    
    @State private var dividerPosition: CGFloat = 0.5
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clipX = max(0.0, min(1.0, dividerPosition + (dragOffset / w)))
            ZStack {
                // Original (left)
                Image(decorative: original, scale: 1.0)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: w, height: geo.size.height)
                    .clipped()
                
                // Processed (right) clipped to divider
                Image(decorative: processed, scale: 1.0)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: w, height: geo.size.height)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(width: w * clipX)
                            .alignmentGuide(.leading) { _ in 0 }
                    )
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2)
                    .offset(x: (clipX * w) - (w / 2))
                    .shadow(radius: 1)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let delta = value.translation.width / w
                                dividerPosition = max(0.05, min(0.95, dividerPosition + delta))
                            }
                    )
                
                // Labels
                VStack {
                    HStack {
                        Text("Before")
                            .font(.caption2.weight(.semibold))
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                        Spacer()
                        Text("After")
                            .font(.caption2.weight(.semibold))
                            .padding(6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

#if DEBUG
struct BeforeAfterView_Previews: PreviewProvider {
    static var previews: some View {
        // placeholder images with solid color for preview
        let img = CGImage(width: 64, height: 64, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 64 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: CGDataProvider(data: Data(repeating: 0xFF, count: 64 * 64 * 4) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        BeforeAfterView(original: img, processed: img)
            .frame(height: 300)
    }
}
#endif
