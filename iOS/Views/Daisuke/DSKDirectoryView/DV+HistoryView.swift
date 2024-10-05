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

        @State var presentAlert = false
        @State var token: NotificationToken?
        @State var results: [UpdatedSearchHistory] = []
        var body: some View {
            SmartNavigationView {
                List {
                    ForEach(results) { result in
                        Cell(for: result)
                            .swipeActions {
                                Button(role: .destructive) {
                                    let id = result.id
                                    Task {
                                        let actor = await RealmActor.shared()
                                        await actor.deleteSearch(id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
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
                .animation(.default, value: results)
                .task {
                    await observe()
                }
                .onDisappear(perform: cancel)
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
        let runnerId = model.runner.id
        Task {
            let actor = await RealmActor.shared()
            await actor.deleteSearchHistory(for: runnerId)
        }
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

extension DirectoryView.HistoryView {
    func observe() async {
        let actor = await RealmActor.shared()
        token = await actor.observeSearchHistory(id: model.runner.id) { value in
            results = value
        }
    }

    func cancel() {
        token?.invalidate()
        token = nil
    }
}
