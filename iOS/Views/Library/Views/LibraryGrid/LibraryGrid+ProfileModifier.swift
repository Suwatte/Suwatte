//
//  LibraryGrid+ProfileModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import SwiftUI

extension LibraryView.LibraryGrid {
    struct CollectionModifier: ViewModifier {
        @Binding var selection: LibraryEntry?
        @EnvironmentObject var model: ViewModel
        @State var isActive = false
        func body(content: Content) -> some View {
            content
                .background(HiddenLink)
                .onChange(of: selection) { val in
                    if val != nil {
                        isActive.toggle()
                    }
                }
        }

        @ViewBuilder
        var HiddenLink: some View {
            if let content = selection?.content {
                NavigationLink(isActive: $isActive,
                               destination: {
                                   LazyView(ProfileView(entry: content.toHighlight(), sourceId: content.sourceId))

                               },
                               label: { EmptyView() })
                    .onChange(of: isActive) { newValue in
                        if !newValue {
                            selection = nil
                        }
                    }
                    .buttonStyle(NeutralButtonStyle())
                    .disabled(model.isSelecting)
            }
        }
    }

    struct ProfileModifier: ViewModifier {
        @State var isActive = false
        var entry: LibraryEntry
        func body(content: Content) -> some View {
            content
                .onTapGesture {
                    isActive.toggle()
                }
                .background(HiddenLink)
        }

        @ViewBuilder
        var HiddenLink: some View {
            if let readable = entry.content {
                NavigationLink(isActive: $isActive,
                               destination: {
                                   LazyView(ProfileView(entry: readable.toHighlight(), sourceId: readable.sourceId))

                               },
                               label: { EmptyView() })
            }
        }
    }
}
