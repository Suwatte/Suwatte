//
//  ExploreSearchView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

extension ExploreView {
    struct SearchView: View {
        @StateObject var model: ViewModel
        var tagLabel: String?
        @State var initialized = false
        @State var firstCall = false
        @State var presentSearchHistory = false
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
        @Preference(\.useDirectory) var useDirectory

        var body: some View {
            LoadableView(loadable: model.result) {
                ProgressView()
                    .task {
                        await model.makeRequest()
                    }
            } _: {
                ProgressView()
            } _: { error in
                ErrorView(error: error, action: defaultCall)
            } _: { value in
                ResultsView(entries: value)
            }

            // MARK: Filter Sheet

            .fullScreenCover(isPresented: $model.presentFilters, onDismiss: defaultCall) {
                FilterSheet()
                    .tint(accentColor)
                    .accentColor(accentColor)
            }

            // MARK: History Sheet

            .sheet(isPresented: $presentSearchHistory, onDismiss: defaultCall) {
                HistoryView()
                    .tint(accentColor)
                    .accentColor(accentColor)
            }
            .onAppear(perform: {
                if let query = model.request.query, !model.result.LOADED {
                    model.query = query
                }

            })

            // MARK: Navigation

            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(NAV_TITLE)
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main), perform: didRecieveQuery(_:))
            .onSubmit(of: .search, didSubmitSearch)
            .environmentObject(model.source) // Required for Highlight Navigation
            .environmentObject(model) // Required for Result Count
            .animation(.default, value: model.result)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !IS_TAG_VIEW {
                        Button { model.presentFilters.toggle() } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }

                        Button { presentSearchHistory.toggle() } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
            }
        }

        // MARK: Computed

        var NAV_TITLE: String {
            if let tagLabel = tagLabel {
                return "\(tagLabel) Titles"
            } else {
                if let source = model.source as? DSK.LocalContentSource, source.hasExplorePage && !useDirectory {
                    return "Search"
                } else {
                    return "Directory"
                }
            }
        }

        var IS_TAG_VIEW: Bool {
            tagLabel != nil
        }

        // MARK: Functions

        func defaultCall() {
            Task {
                await model.makeRequest()
            }
        }

        func initialRequest() {
            if initialized {
                return
            }
            defaultCall()
            initialized.toggle()
        }

        func didSubmitSearch() {
            DataManager.shared.saveSearch(model.query, sourceId: model.source.id)
        }

        func didRecieveQuery(_ val: String) {
            if model.callFromHistory {
                model.callFromHistory.toggle()
                return
            }
            if !firstCall {
                firstCall.toggle()
                return
            }

            model.softReset()

            if val.isEmpty {
                defaultCall()
                return
            }
            model.request.query = val
                .trimmingCharacters(in: .whitespacesAndNewlines)
            defaultCall()
        }
    }
}
