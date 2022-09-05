//
//  LibraryGrid+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import Combine
import Foundation

extension LibraryView.LibraryGrid {
    final class ViewModel: ObservableObject {
        @Published var searchQuery = ""

        // Sheets
        @Published var presentOptionsSheet = false

        // Selections
        @Published var isSelecting = false {
            didSet {
                // Clear Selections when user exits selection mode
                if !isSelecting {
                    selectedIndexes.removeAll()
                }
            }
        }

        @Published var selectedIndexes: Set<Int> = []
        @Published var navSelection: LibraryEntry?
    }
}
