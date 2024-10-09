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

        var regularEntries: [LibraryEntry]
        var pinnedEntries: [LibraryEntry]

        @State var selectionOption: SelectionOption?
        @State var confirmRemoval = false
        @EnvironmentObject var model: ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        private var migrationSelections: [TaggedHighlight] {
            selectedEntries
                .compactMap(\.content)
                .map { .init(from: $0.toHighlight(), with: $0.sourceId) }
        }

        func body(content: Content) -> some View {
            content
                .fullScreenCover(item: $selectionOption) { option in
                    Group {
                        switch option {
                        case .collections: MoveCollectionsView(entries: selectedEntries)
                        case .flags: MoveReadingFlag(entries: selectedEntries)
                        case .migrate:
                            SmartNavigationView {
                                MigrationView(model: .init(contents: migrationSelections))
                                    .toolbar {
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Cancel") {
                                                selectionOption = nil
                                            }
                                        }
                                    }
                            }
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
                    Text("Are you sure you want to remove these \(selectedCount) titles from your library?")

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
                            if didSelectSomething {
                                Text("^[\(selectedCount) Selection](inflect: true)")
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
            model.selectedPinnedIndexes = Set(pinnedEntries.indices.map { $0 })
            model.selectedRegularIndexes = Set(regularEntries.indices.map { $0 })
        }

        func deselectAll() {
            model.clearSelection()
        }

        func invert() {
            let allRegular = Set(regularEntries.indices)
            model.selectedRegularIndexes = model.selectedRegularIndexes.symmetricDifference(allRegular)

            let allPinned = Set(pinnedEntries.indices)
            model.selectedPinnedIndexes = model.selectedPinnedIndexes.symmetricDifference(allPinned)
        }

        func fillRange() {
            if !didSelectSomething { return }

            let pinnedIndexes = model.selectedPinnedIndexes.sorted()
            let pinnedStart = pinnedIndexes.first
            let pinnedEnd = pinnedIndexes.last

            let regularIndexes = model.selectedRegularIndexes.sorted()

            let regularStart = regularIndexes.first
            let regularEnd = regularIndexes.last

            if pinnedStart != nil {
                var end = 0
                if regularStart != nil {
                    end = pinnedEntries.endIndex - 1
                } else if let pinnedEnd {
                    end = pinnedEnd
                }
                model.selectedPinnedIndexes = Set(pinnedEntries.indices[pinnedStart! ... end])
            }

            let start = pinnedStart != nil && regularStart != nil ? 0 : regularStart!
            let end = regularEnd != nil ? regularEnd! : 0

            if end > start {
                model.selectedRegularIndexes = Set(regularEntries.indices[start ... end])
            }
        }

        func removeFromLibrary() {
            let targets = selectedEntries
                .map { $0.id }

            Task {
                let actor = await Suwatte.RealmActor.shared()
                await actor.batchRemoveFromLibrary(with: Set(targets))
            }

            DispatchQueue.main.async {
                deselectAll()
            }
        }

        var selectedEntries: [LibraryEntry] {
            let regularSelectedEntries = zip(regularEntries.indices, regularEntries)
                .filter { model.selectedRegularIndexes.contains($0.0) }
                .map { $0.1 }

            let pinnedSelectedEntries = zip(pinnedEntries.indices, pinnedEntries)
                .filter { model.selectedPinnedIndexes.contains($0.0) }
                .map { $0.1 }

            return regularSelectedEntries + pinnedSelectedEntries
        }

        var didSelectSomething: Bool {
            return !model.selectedPinnedIndexes.isEmpty || !model.selectedRegularIndexes.isEmpty
        }

        var selectedCount: Int {
            if !didSelectSomething {
                return 0
            }

            return model.selectedPinnedIndexes.count + model.selectedRegularIndexes.count
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
