//
//  +VerticalSlider.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

struct ReaderVSlider: View {
    @Binding var value: Double
    @Binding var isScrolling: Bool
    @State var lastOffset: Double = 0
    var range: ClosedRange<Double>
    @Environment(\.colorScheme) var colorScheme

    var knobSize: CGSize = .init(width: 25, height: 25)
    var barSize: CGFloat

    var backgroundBarColor: Color { colorScheme == .dark ? Color(hex: "3d3d40") : .init(hex: "58585C") }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // BackGround
                RoundedRectangle(cornerRadius: 50)
                    .frame(width: barSize)
                    .foregroundColor(backgroundBarColor)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(backgroundBarColor, lineWidth: 1.5)
                    }

                // Trailing
                RoundedRectangle(cornerRadius: 50)
                    .foregroundColor(Color.accentColor)
                    .frame(width: barSize, height: $value.wrappedValue.map(from: range, to: (knobSize.width) ... (geometry.size.height)))

                // Knob
                RoundedRectangle(cornerRadius: 50)
                    .frame(width: knobSize.width, height: knobSize.height)
                    .foregroundColor(.white)
                    .scaleEffect(isScrolling ? 1.2 : 1.0)
                    .shadow(color: .black, radius: 2)
                    .offset(y: $value.wrappedValue.map(from: range, to: 0 ... (geometry.size.height - knobSize.width)))
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
