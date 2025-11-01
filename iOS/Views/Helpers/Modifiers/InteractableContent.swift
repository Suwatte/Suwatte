//
//  InteractableContent.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-06.
//

import RealmSwift
import SwiftUI

struct ProfileNavigationDestination: Hashable {
    let entryId: String
    let entryTitle: String
    let entryCover: String
    let sourceId: String

    init(entry: DaisukeEngine.Structs.Highlight, sourceId: String) {
        self.entryId = entry.id
        self.entryTitle = entry.title
        self.entryCover = entry.cover
        self.sourceId = sourceId
    }

    func toHighlight() -> DaisukeEngine.Structs.Highlight {
        DaisukeEngine.Structs.Highlight(id: entryId, cover: entryCover, title: entryTitle)
    }
}

struct InteractableContent: ViewModifier {
    var entry: DaisukeEngine.Structs.Highlight
    var sourceId: String
    @Environment(\.redactionReasons) var reasons
    func body(content: Content) -> some View {
        NavigationLink(value: ProfileNavigationDestination(entry: entry, sourceId: sourceId)) {
            content
        }
        .buttonStyle(NeutralButtonStyle())
    }
}

struct HighlightIdentifier: Equatable {
    var sourceId: String
    var sourceName: String?
    var entry: DaisukeEngine.Structs.Highlight
}

struct InteractableContainer: ViewModifier {
    @Binding var selection: HighlightIdentifier?
    @State private var isNavigating = false
    @State private var destination: ProfileNavigationDestination?

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $isNavigating) {
                if let destination = destination {
                    ProfileView(entry: destination.toHighlight(), sourceId: destination.sourceId)
                }
            }
            .onChange(of: selection) { newSelection in
                if let newSelection = newSelection {
                    destination = ProfileNavigationDestination(entry: newSelection.entry, sourceId: newSelection.sourceId)
                    isNavigating = true
                    // Clear after navigation is initiated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selection = nil
                    }
                }
            }
            .onChange(of: isNavigating) { navigating in
                if !navigating {
                    destination = nil
                }
            }
            .onAppear {
                selection = nil
            }
    }
}

// MARK: - Hidden Navigation (NavigationStack compatible)

struct HiddenNavigationModifier<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var destination: () -> Destination

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $isPresented) {
                destination()
            }
    }
}

extension View {
    /// Hidden navigation helper compatible with NavigationStack
    /// Use this for programmatic navigation triggered by state changes
    func hiddenNav<T: View>(presenting: Binding<Bool>, @ViewBuilder _ view: @escaping () -> T) -> some View {
        modifier(HiddenNavigationModifier(isPresented: presenting, destination: view))
    }
}
