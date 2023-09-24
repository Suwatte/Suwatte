//
//  SelectionLabel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import SwiftUI

struct SelectionLabel: View {
    var label: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            withAnimation {
                action()
            }
        } label: {
            HStack {
                Text(label)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
        }
    }
}

struct SelectionView: View {
    @Binding var selection: Option
    @State var options: [Option]
    var title: String = "Selection"
    var body: some View {
        NavigationLink(destination: MAIN_BODY) {
            HStack {
                Text(title)
                Spacer()
                Text(selection.label)
                    .foregroundColor(.gray)
            }
        }
    }

    var MAIN_BODY: some View {
        List {
            ForEach(options) { option in
                Button { didSelectOption(option) } label: {
                    HStack {
                        Text(option.label)
                            .fontWeight(.light)
                        Spacer()
                        Image(systemName: "checkmark")
                            .opacity(selection.id == option.id ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.default, value: selection.value)
        .navigationTitle(title)
    }

    func didSelectOption(_ option: Option) {
        withAnimation {
            selection = option
        }
    }

    struct Option: Identifiable {
        var label: String
        var value: String

        var id: String {
            value
        }
    }
}

struct MultiSelectionView<A: RandomAccessCollection, Content: View>: View where A.Element: Identifiable & Hashable {
    typealias SelectionSet = Set<A.Element>
    typealias CellView = (A.Element) -> Content
    let options: A
    let cell: CellView

    @Binding var selected: SelectionSet

    init(options: A, selection: Binding<SelectionSet>, @ViewBuilder _ content: @escaping CellView) {
        self.options = options
        cell = content
        _selected = selection
    }

    var body: some View {
        List {
            ForEach(options) { selectable in
                Button(action: { toggleSelection(selectable: selectable) }) {
                    HStack {
                        cell(selectable)

                        Spacer()

                        if selected.contains(where: { $0.id == selectable.id }) {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                                .transition(.opacity)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .tag(selectable.id)
                .buttonStyle(.plain)
            }
        }
        .animation(.default, value: selected)
    }

    private func toggleSelection(selectable: A.Element) {
        withAnimation {
            if selected.contains(selectable) {
                selected.remove(selectable)
            } else {
                selected.insert(selectable)
            }
        }
    }
}
