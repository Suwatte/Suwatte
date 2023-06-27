//
//  RefreshableScrollView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import SwiftUI

public struct ViewOffsetKey: PreferenceKey {
    public typealias Value = CGFloat
    public static var defaultValue = CGFloat.zero
    public static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

struct RefreshableView<Content: View>: View {
    var content: () -> Content

    @Environment(\.refresh) private var refresh // << refreshable injected !!
    @State private var isRefreshing = false

    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if isRefreshing {
                ProgressView() // ProgressView() ?? - no, it's boring :)
                    .transition(.opacity)
                    .padding(.vertical, 3)
            }
            content()
        }
        .animation(.default, value: isRefreshing)
        .background(GeometryReader {
            // detect Pull-to-refresh
            Color.clear.preference(key: ViewOffsetKey.self, value: -$0.frame(in: .global).origin.y)
        })
        .onPreferenceChange(ViewOffsetKey.self) {
            if $0 < -200, !isRefreshing { // << any creteria we want !!
                isRefreshing = true
                Task {
                    try? await Task.sleep(nanoseconds: 1 * 1_500_000_000)
                    await refresh?() // << call refreshable !!
                    await MainActor.run {
                        isRefreshing = false
                    }
                }
            }
        }
    }
}
