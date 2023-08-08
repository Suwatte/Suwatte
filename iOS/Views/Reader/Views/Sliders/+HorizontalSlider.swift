//
//  +HorizontalSlider.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

struct HorizontalSlider: View {
    @Binding var value: CGFloat
    @Binding var isScrolling: Bool
    @State var lastOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    var range: ClosedRange<CGFloat>
    
    var knobSize: CGSize = .init(width: 17, height: 17)
    
    func completionOpacity() -> Double {
        let out = value / range.upperBound
        return Double(out)
    }
    
    func scrollColor() -> Color {
        isScrolling || value >= range.upperBound ? Color.accentColor : Color(hex: "77777D")
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                    // Cover
                    
                    // BG
                    RoundedRectangle(cornerRadius: 50)
                        .frame(height: 5)
                        .foregroundColor(colorScheme == .dark ? Color(hex: "3d3d40") : .init(hex: "58585C"))
                    
                    // Trailing
                    
                    RoundedRectangle(cornerRadius: 50)
                        .foregroundColor(scrollColor())
                        .frame(width: $value.wrappedValue.map(from: range,
                                                              to: (knobSize.width) ... max(geometry.size.width, knobSize.width)),
                               height: 5)
                    
                    // KNOB
                    RoundedRectangle(cornerRadius: 50)
                        .frame(width: knobSize.width, height: knobSize.height, alignment: .center)
                        .foregroundColor(.white)
                        .offset(x: $value.wrappedValue.map(from: range, to: 0 ... max(geometry.size.width - knobSize.width, 0)))
                        .shadow(radius: 8)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isScrolling = true
                                    if abs(value.translation.width) < 0.1 {
                                        lastOffset = $value.wrappedValue.map(from: range, to: 0 ... (geometry.size.width - knobSize.width))
                                    }
                                    
                                    let sliderPos = max(0, min(lastOffset + value.translation.width, geometry.size.width - knobSize.width))
                                    let sliderVal = sliderPos.map(from: 0 ... (geometry.size.width - knobSize.width), to: range)
                                    
                                    self.value = sliderVal
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        isScrolling = false
                                    }
                                }
                        )
                }
            }
        }
        .frame(height: knobSize.height)
    }
}
