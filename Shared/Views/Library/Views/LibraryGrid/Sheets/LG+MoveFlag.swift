//
//  LG+MoveFlag.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-27.
//

import SwiftUI
import RealmSwift

enum SelectionState {
    case none, some, all
}

extension LibraryView.LibraryGrid {
    
    
    struct MoveReadingFlag: View {
        var entries: Results<LibraryEntry>
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            NavigationView {
                List {
                    Section {
                        ForEach(LibraryFlag.allCases) { flag in
                            let state = state(for: flag)
                            Button { setFlags(flag) } label: {
                                HStack {
                                    Text(flag.description)
                                    Spacer()
                                    Group {
                                        switch state {
                                            case .none:
                                                EmptyView()
                                            case .some:
                                                Text("-")
                                            case .all:
                                                Image(systemName: "checkmark")

                                        }
                                    }
                                    .font(.body.weight(.light))
                                    .foregroundColor(.gray)
                                }
                            }

                        }
                    } header: {
                        Text("Flags")
                    }
                }
                .closeButton()
                .navigationTitle("Change Reading Flag")
                .buttonStyle(.plain)
            }
        }
        
        func setFlags(_ flag: LibraryFlag) {
            let ids = Set(entries.map(\._id))
            DataManager.shared.bulkSetReadingFlag(for: ids, to: flag)
            presentationMode.wrappedValue.dismiss()
            
        }
    }
}


extension LibraryView.LibraryGrid.MoveReadingFlag {
    
    func state(for flag: LibraryFlag) -> SelectionState {
        
        if entries.allSatisfy({ $0.flag == flag }) {
            return .all
        } else if entries.contains(where: { $0.flag == flag }) {
            return .some
        } else {
            return .none
        }
    }
    
    func selectionBadge(for state: SelectionState) -> String {
        switch state {
            case .none:
                return ""
            case .some:
                return "-"
            case .all:
                return "\(Image(systemName: "checkmark"))"
        }
    }
}

