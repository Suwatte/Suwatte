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
        @ObservedResults(UpdatedSearchHistory.self, where: { $0.isDeleted == false }) var results
        @ObservedObject var toastManager = ToastManager()

        @EnvironmentObject var model: DirectoryView.ViewModel
        @Environment(\.presentationMode) var presentationMode

        @State var presentAlert = false
        var body: some View {
            let filtered = results.where { $0.sourceId == model.runner.id }
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
                .navigationBarTitleDisplayMode(.inline)
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

extension DirectoryView.HistoryView {
    func Cell(for data: UpdatedSearchHistory) -> some View {
        Button { didTap(data) } label: {
            Text(data.displayText)
                .font(.body.weight(.light))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension DirectoryView.HistoryView {
    func handleClear() {
        ToastManager.shared.loading.toggle()
        DataManager.shared.deleteSearchHistory(for: model.runner.id)
        ToastManager.shared.loading.toggle()
    }

    func didTap(_ entry: UpdatedSearchHistory) {
        model.reset()
        do {
            let request = try DSK.parse(entry.data, to: DSKCommon.DirectoryRequest.self)
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
