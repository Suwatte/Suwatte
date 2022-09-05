//
//  MSInteractableTag.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-02.
//

import SwiftUI

extension Text {
    func msTag() -> some View {
        fontWeight(.semibold)
            .font(.callout)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.1))
            .foregroundColor(Color.primary)
            .cornerRadius(5)
    }
}

struct InteractiveTagCell<Content: View>: View {
    var label: String
    var destination: () -> Content

    init(_ label: String, @ViewBuilder _ content: @escaping () -> Content) {
        self.label = label
        destination = content
    }

    var body: some View {
        NavigationLink(destination: destination) {
            Text(label)
                .msTag()
        }
    }
}
