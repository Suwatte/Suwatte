//
//  +VerticalSlider.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

struct VerticalSlider: View {
    @Binding var value: CGFloat
    @Binding var isScrolling: Bool
    @State var lastOffset: CGFloat = 0
    var range: ClosedRange<CGFloat>
    
    var knobSize: CGSize = .init(width: 17, height: 17)
    func scrollColor() -> Color {
        isScrolling || value >= range.upperBound ? Color.accentColor : Color(hex: "77777d")
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // BackGround
                RoundedRectangle(cornerRadius: 50)
                    .frame(width: 5)
                    .foregroundColor(.init(hex: "3d3d40"))
                
                // Trailing
                RoundedRectangle(cornerRadius: 50)
                    .foregroundColor(scrollColor())
                    .frame(width: 5, height: $value.wrappedValue.map(from: range, to: (knobSize.width) ... (geometry.size.height)))
                
                // Knob
                RoundedRectangle(cornerRadius: 50)
                    .frame(width: knobSize.width, height: knobSize.height)
                    .foregroundColor(.white)
                    .offset(y: $value.wrappedValue.map(from: range, to: 0 ... (geometry.size.height - knobSize.width)))
                    .shadow(radius: 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isScrolling = true
                                
                                if abs(value.translation.height) < 0.1 {
                                    lastOffset = $value.wrappedValue.map(from: range, to: 0 ... (geometry.size.height - knobSize.height))
                                }
                                
                                let sliderPos = max(0, min(lastOffset + value.translation.height, geometry.size.height - knobSize.width))
                                let sliderVal = sliderPos.map(from: 0 ... (geometry.size.height - knobSize.width), to: range)
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
        .frame(width: knobSize.width)
    }
}
