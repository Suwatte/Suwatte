//
//  LazyView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-06.
//

import SwiftUI

// Reference : https://stackoverflow.com/a/58696110

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}
