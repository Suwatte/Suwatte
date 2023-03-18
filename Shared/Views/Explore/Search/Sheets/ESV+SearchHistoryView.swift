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
        @ObservedResults(UpdatedSearchHistory.self) var results
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
                .toast()
                .animation(.default, value: results)
            }
        }
    }
}

extension ExploreView.SearchView.HistoryView {
    func Cell(for data: UpdatedSearchHistory) -> some View {
        Button { didTap(data) } label: {
            Text(data.displayText)
                .font(.body.weight(.light))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ExploreView.SearchView.HistoryView {
    func handleClear() {
        ToastManager.shared.loading.toggle()
        DataManager.shared.deleteSearchHistory(for: model.source.id)
        ToastManager.shared.loading.toggle()
    }

    func didTap(_ entry: UpdatedSearchHistory) {
        model.softReset()
        do {
            let request = try DSK.parse(entry.data, to: DSKCommon.SearchRequest.self)
            model.callFromHistory = true
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
