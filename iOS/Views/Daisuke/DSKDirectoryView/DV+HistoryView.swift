//
//  DV+HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import RealmSwift
import SwiftUI

extension DirectoryView {
    struct HistoryView: View {
        @EnvironmentObject var model: DirectoryView.ViewModel
        @Environment(\.presentationMode) var presentationMode
        @FetchRequest(fetchRequest: CDSearchHistory.globalSearchRequest(), animation: .default)
        private var history: FetchedResults<CDSearchHistory>
        
        @State var presentAlert = false
        
        init() {
            let request = CDSearchHistory.singleSourceRequest(id: model.runner.id)
            self._history = FetchRequest(fetchRequest: request, animation: .default)
        }
        
        var body: some View {
            SmartNavigationView {
                List {
                    ForEach(history) { result in
                        Cell(for: result)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    CDSearchHistory.remove(result)
                                }
                            }
                    }
                }
                .navigationTitle("Search History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                presentAlert.toggle()
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .closeButton()
                .alert("Are you sure you want to clear all history", isPresented: $presentAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        handleClear()
                    }
                }
                .toast()
            }
        }
    }
}

extension DirectoryView.HistoryView {
    func Cell(for data: CDSearchHistory) -> some View {
        Button { didTap(data) } label: {
            Text(data.display)
                .font(.body.weight(.light))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension DirectoryView.HistoryView {
    func handleClear() {
        let runnerId = model.runner.id
        CDSearchHistory.remove(for: runnerId)
    }
    
    func didTap(_ entry: CDSearchHistory) {
        model.reset()
        
        guard let data = entry.request else {
            model.query = entry.display
            return
        }
        
        do {
            let request = try JSONDecoder().decode(DSKCommon.DirectoryRequest.self, from: data)
            model.request = request
            if let q = request.query {
                model.query = q
            }
        } catch {
            Logger.shared.error("\(error)")
            ToastManager.shared.error(error)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
