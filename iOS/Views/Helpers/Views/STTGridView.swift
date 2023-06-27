//
//  STTGridView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-16.
//

import ASCollectionView
import SwiftUI

struct STTGridView<A: RandomAccessCollection, Content: View>: View where A.Element: Identifiable, A.Index == Int {
    var items: A
    var spacing: CGFloat
    var content: (A.Element) -> Content
    var header: (() -> Content)?
    var footer: (() -> Content)?

    init(items: A, spacing: CGFloat = 5, @ViewBuilder _ content: @escaping (A.Element) -> Content) {
        self.items = items
        self.content = content
        self.spacing = spacing
    }

//    var height: CGFloat {
//        let safeAreaInsets = (KEY_WINDOW?.safeAreaInsets.left ?? 0) + (KEY_WINDOW?.safeAreaInsets.right ?? 0)
//        let width = (UIScreen.main.bounds.width - safeAreaInsets) / CGFloat(columns.count)
    ////        let targetRatio = useDefaultStyling || ratio == nil ? styling.tileRatio : ratio!
    ////        return width * targetRatio
//    }

    var body: some View {
        ASCollectionView(data: items) { item, _ in
            content(item)
        }
        .layout {
            .grid(
                layoutMode: .adaptive(withMinItemSize: 100),
                itemSpacing: 5,
                lineSpacing: 5,
                itemSize: .absolute(50)
            )
        }
    }

//    var GRID_VIEW: some View {
//        LazyVGrid(columns: columns, spacing: spacing) {
//            ForEach(items) { item in
//                GeometryReader { _ in
//                    content(item)
//                }
//                .frame(height: height)
//            }
//        }
//        .padding(.vertical, 5)
//        .padding(.horizontal)

//    }
}
