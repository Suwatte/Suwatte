//
//  LibraryGrid+ProfileModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import SwiftUI

extension LibraryView.LibraryGrid {
    // Navigation destination for NavigationStack
    struct ProfileDestination: Hashable {
        let contentId: String
        let sourceId: String
        let title: String
        let cover: String

        init(from content: StoredContent) {
            self.contentId = content.contentId
            self.sourceId = content.sourceId
            self.title = content.title
            self.cover = content.cover
        }

        func toHighlight() -> DaisukeEngine.Structs.Highlight {
            DaisukeEngine.Structs.Highlight(id: contentId, cover: cover, title: title)
        }
    }

    struct CollectionModifier: ViewModifier {
        @Binding var selection: LibraryEntry?
        @EnvironmentObject var model: ViewModel
        @State private var isNavigating = false
        @State private var destination: ProfileDestination?

        func body(content: Content) -> some View {
            content
                .navigationDestination(isPresented: $isNavigating) {
                    if let destination = destination {
                        ProfileView(entry: destination.toHighlight(), sourceId: destination.sourceId)
                    }
                }
                .onChange(of: selection) { entry in
                    guard let entry = entry, let content = entry.content else { return }
                    destination = ProfileDestination(from: content)
                    isNavigating = true
                    // Clear selection after navigation is initiated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selection = nil
                    }
                }
                .onChange(of: isNavigating) { navigating in
                    if !navigating {
                        destination = nil
                    }
                }
        }
    }

    struct ProfileModifier: ViewModifier {
        var entry: LibraryEntry

        func body(content: Content) -> some View {
            if let readable = entry.content {
                NavigationLink(value: ProfileDestination(from: readable)) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}
