//
//  +HorizontalSlider.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

struct ReaderHSlider: View {
    @Binding var value: Double
    @Binding var isScrolling: Bool
    @State var lastOffset: Double = 0
    @Environment(\.colorScheme) var colorScheme
    var range: ClosedRange<Double>

    var knobSize: CGSize = .init(width: 25, height: 25)
    var barSize: CGFloat

    var backgroundBarColor: Color { colorScheme == .dark ? Color(hex: "3d3d40") : .init(hex: "58585C") }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
                    // Cover

                    // BG
                    RoundedRectangle(cornerRadius: 50)
                        .frame(height: barSize)
                        .foregroundColor(backgroundBarColor)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(backgroundBarColor, lineWidth: 1.5)
                        }

                    // Trailing

                    RoundedRectangle(cornerRadius: 50)
                        .foregroundColor(Color.accentColor)
                        .frame(width: $value.wrappedValue.map(from: range,
                                                              to: (knobSize.width) ... max(geometry.size.width, knobSize.width)),
                               height: barSize)

                    // KNOB
                    RoundedRectangle(cornerRadius: 50)
                        .frame(width: knobSize.width, height: knobSize.height, alignment: .center)
                        .foregroundColor(.white)
                        .scaleEffect(isScrolling ? 1.2 : 1.0)
                        .shadow(color: .black, radius: 2)
                        .offset(x: $value.wrappedValue.map(from: range, to: 0 ... max(geometry.size.width - knobSize.width, 0)))
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
