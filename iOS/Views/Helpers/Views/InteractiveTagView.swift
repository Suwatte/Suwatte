//
//  InteractiveTagView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

// Reference: https://stackoverflow.com/a/62103264
struct InteractiveTagView<T: RandomAccessCollection, Content: View>: View where T.Element: Identifiable {
    @State private var totalHeight
        = CGFloat.zero // << variant for ScrollView/List
    //    = CGFloat.infinity   // << variant for VStack
    var content: (_ t: T.Element) -> Content
    var tags: T

    init(_ tags: T, @ViewBuilder _ content: @escaping (_ tag: T.Element) -> Content) {
        self.tags = tags
        self.content = content
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight) // << variant for ScrollView/List
        // .frame(maxHeight: totalHeight) // << variant for VStack
    }

    @ViewBuilder
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        ZStack(alignment: .topLeading) {
            ForEach(tags) { tag in
                content(tag)
                    .padding(.all, 3.5)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > g.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if tag.id == self.tags.last!.id {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if tag.id == self.tags.last!.id {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }.background(viewHeightReader($totalHeight))
    }

    func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)

            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }

    func viewSizeReader(_ binding: Binding<CGSize>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)

            DispatchQueue.main.async {
                binding.wrappedValue = rect.size
            }
            return .clear
        }
    }
}
