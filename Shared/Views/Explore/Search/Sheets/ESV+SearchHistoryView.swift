//
//  ESV+SearchHistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-05.
//

import RealmSwift
import SwiftUI

extension ExploreView.SearchView {
    struct HistoryView: View {
        @ObservedResults(SearchHistory.self) var results
        @ObservedObject var toastManager = ToastManager()

        @EnvironmentObject var model: ExploreView.SearchView.ViewModel
        @Environment(\.presentationMode) var presentationMode

        @State var presentAlert = false
        var body: some View {
            let filtered = results.where { $0.sourceId == model.source.id }
            NavigationView {
                List {
                    ForEach(filtered) { result in
                        Cell(for: result)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    DataManager.shared.deleteSearch(result)
                                }
                            }
                    }
                }
                .navigationTitle("Search History")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("\(Image(systemName: "trash"))") { presentAlert.toggle() }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                    }
                }
                .closeButton()
                .alert("Are you sure you want to clear all history", isPresented: $presentAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        handleClear()
                    }
                }
                .toast(isPresenting: $toastManager.show) {
                    toastManager.toast
                }

                .animation(.default, value: toastManager.show)
                .animation(.default, value: results)
            }
        }
    }
}

extension ExploreView.SearchView.HistoryView {
    func Cell(for data: SearchHistory) -> some View {
        Button { didTap(data) } label: {
            Text(data.label)
                .font(.body.weight(.light))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ExploreView.SearchView.HistoryView {
    func handleClear() {
        toastManager.setToast(toast: .init(type: .loading))
        DataManager.shared.deleteSearchHistory(for: model.source.id)
        toastManager.show.toggle()
    }

    func didTap(_ entry: SearchHistory) {
        // Unecessarily confusing
        model.softReset()
        model.callFromHistory = true
        model.query = entry.text ?? ""
        model.request.query = entry.text
        model.request.includedTags = entry.included.toArray()
        model.request.excludedTags = entry.excluded.toArray()
        presentationMode.wrappedValue.dismiss()
    }
}
