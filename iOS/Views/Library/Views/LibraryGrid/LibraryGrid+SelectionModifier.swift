//
//  LibraryGrid+SelectionModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import RealmSwift
import SwiftUI
extension LibraryView.LibraryGrid {
    struct SelectionModifier: ViewModifier {
        enum SelectionOption: Identifiable {
            var id: Int {
                return hashValue
            }

            case collections, flags, migrate
        }

        var entries: [LibraryEntry]
        @State var selectionOption: SelectionOption?
        @State var confirmRemoval = false
        @EnvironmentObject var model: ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        func body(content: Content) -> some View {
            content
                .fullScreenCover(item: $selectionOption, onDismiss: { model.selectedIndexes.removeAll() }) { option in
                    Group {
                        switch option {
                        case .collections: MoveCollectionsView(entries: entries)
                        case .flags: MoveReadingFlag(entries: entries)
                        case .migrate:
                            NavigationView {
                                MigrationView(contents: selectedEntries.compactMap(\.content))
                                    .toolbar {
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Cancel") {
                                                selectionOption = nil
                                            }
                                        }
                                    }
                            }
                            .navigationViewStyle(.stack)
                        }
                    }
                    .accentColor(accentColor)
                    .tint(accentColor)
                }
                .alert("Remove From Library", isPresented: $confirmRemoval, actions: {
                    Button("Proceed", role: .destructive) {
                        removeFromLibrary()
                    }
                }, message: {
                    Text("Are you sure you want to remove these \(model.selectedIndexes.count) titles from your library?")

                })
                .modifier(ConditionalToolBarModifier(showBB: $model.isSelecting))
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if model.isSelecting {
                            Menu("Select") {
                                Button("Invert") { withAnimation { invert() }}
                                Button("Fill range") { withAnimation { fillRange() } }
                                Button("Deselect All") { withAnimation { deselectAll() } }
                                Button("Select All") { withAnimation { selectAll() } }
                            }
                            .padding()
                            Spacer()
                            if !model.selectedIndexes.isEmpty {
                                Menu("Options") {
                                    Button(role: .destructive) { confirmRemoval.toggle() } label: {
                                        Label("Remove From Library", systemImage: "trash")
                                    }
                                    Button { selectionOption = .migrate } label: {
                                        Label("Migrate Titles", systemImage: "shippingbox")
                                    }
                                    Button { selectionOption = .flags } label: {
                                        Label("Change Reading Flag", systemImage: "flag")
                                    }
                                    Button { selectionOption = .collections } label: {
                                        Label("Move Collections", systemImage: "archivebox")
                                    }
                                }
                            }
                        }
                    }
                }
        }

        func selectAll() {
            model.selectedIndexes = Set(entries.indices.map { $0 })
        }

        func deselectAll() {
            model.selectedIndexes.removeAll()
        }

        func invert() {
            let all = Set(entries.indices)
            model.selectedIndexes = all.symmetricDifference(all)
        }

        func fillRange() {
            if model.selectedIndexes.isEmpty { return }

            let indexes = model.selectedIndexes.sorted()

            let start = indexes.first!
            let end = indexes.last!

            model.selectedIndexes = Set(entries.indices[start ... end])
        }

        func removeFromLibrary() {
            let targets = zip(entries.indices, entries)
                .filter { model.selectedIndexes.contains($0.0) }
                .map { $0.1.id }

            Task {
                let actor = await Suwatte.RealmActor()
                await actor.batchRemoveFromLibrary(with: Set(targets))
            }

            DispatchQueue.main.async {
                model.selectedIndexes.removeAll()
            }
        }

        var selectedEntries: [LibraryEntry] {
            zip(entries.indices, entries)
                .filter { model.selectedIndexes.contains($0.0) }
                .map { $0.1 }
        }
    }
}

struct ConditionalToolBarModifier: ViewModifier {
    @Binding var showBB: Bool
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content
                .toolbar(showBB ? .visible : .hidden, for: .bottomBar)
        } else {
            content
        }
    }
}
