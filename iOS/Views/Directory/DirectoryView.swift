//
//  DSKDirectoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI


enum PaginationStatus: Equatable {
    case LOADING, END, ERROR(error: Error), IDLE

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.LOADING, .LOADING): return true
        case (.END, .END): return true
        case (.IDLE, .IDLE): return true
        case let (.ERROR(error: lhsE), .ERROR(error: rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}



struct DirectoryView<T: Hashable>: View {
    var body: some View {
        Text("")
    }
}


extension DirectoryView {
    final class DirectoryViewModel: ObservableObject {
        private var runner: JSCRunner

        @Published var result = Loadable<[T]>.idle
        @Published var config: DSKCommon.DirectoryConfig?
        
        
        init(runner: JSCRunner) {
            self.runner = runner
        }
    }
}


