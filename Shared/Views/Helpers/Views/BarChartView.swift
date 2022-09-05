//
//  BarChartView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-23.
//

import SwiftUI

struct BarChart: View {
    var bars: [Bar]
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            ForEach(bars, id: \.label) { bar in
                SingleBarView(bar: bar, max: maximumVal)
            }
        }
    }

    var maximumVal: Int {
        let x = bars.map { $0.value }.max()
        return x!
    }
}

struct SingleBarView: View {
    var bar: Bar
    var max: Int
    var maxHeight = CGFloat(100)
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: 25, height: yValue).foregroundColor(.green)
            }
            Text(bar.label)
                .font(.caption)
                .foregroundColor(Color.white)
        }
        .padding(.bottom, 8)
    }

    var yValue: CGFloat {
        let r = Double(bar.value) / Double(max)
        return CGFloat(r) * maxHeight
    }
}

struct Bar {
    var value: Int
    var label: String
}
