//
//  InteractableContent.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-06.
//

import RealmSwift
import SwiftUI

struct InteractableContent: ViewModifier {
    @State var isActive = false
    var entry: DaisukeEngine.Structs.Highlight
    var sourceId: String
    @Environment(\.redactionReasons) var reasons
    func body(content: Content) -> some View {
        NavigationLink {
            ProfileView(entry: entry, sourceId: sourceId)
        } label: {
            content
        }
        .buttonStyle(NeutralButtonStyle())
    }
}

typealias HighlightIdentifier = (sourceId: String, entry: DaisukeEngine.Structs.Highlight)
struct InteractableContainer: ViewModifier {
    @State private var isActive = false
    @Binding var selection: HighlightIdentifier?
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if let selection = selection {
                        HiddenLink(sourceId: selection.sourceId, entry: selection.entry)
                    }
                }
            )
            .onChange(of: selection?.entry) { _ in
                isActive.toggle()
            }
            .onAppear {
                selection = nil
            }
    }

    func HiddenLink(sourceId: String, entry: DaisukeEngine.Structs.Highlight) -> some View {
        NavigationLink(isActive: $isActive,
                       destination: {
                           ProfileView(entry: entry, sourceId: sourceId)
                       },
                       label: { EmptyView() })
            .buttonStyle(.plain)
            .frame(width: 0)
            .opacity(0)
    }
}

struct V1<A: View>: ViewModifier {
    typealias V = A
    @Binding var isActive: Bool
    var child: () -> A
    func body(content: Content) -> some View {
        content
            .background {
                NavigationLink(isActive: $isActive) {
                    child()
                } label: {
                    EmptyView()
                }
            }
    }
}

extension View {
    func hiddenNav<T: View>(presenting: Binding<Bool>, @ViewBuilder _ view: @escaping () -> T) -> some View {
        modifier(V1(isActive: presenting, child: view))
    }
}
