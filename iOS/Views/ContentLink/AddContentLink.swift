//
//  AddContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-30.
//

import SwiftUI

struct AddContentLink: View {
    let id: String
    let highlight: DSKCommon.Highlight
    @StateObject private var model = SearchView.ViewModel(forLinking: true)
    @AppStorage(STTKeys.TileStyle) private var tileStyle = TileStyle.SEPARATED
    @State private var selection: HighlightIdentifier?
    @State private var isPresenting = false
    @Environment(\.presentationMode) private var presentationMode
    var body: some View {
        List {
            ForEach(model.results, id: \.sourceID) { result in
                SourceSection(result: result)
                    .listRowInsets(.init(top: 5, leading: 0, bottom: 20, trailing: 0))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 0))
        .navigationTitle("Add Content Link")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
        .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main).dropFirst()) { val in
            if val.isEmpty {
                model.results.removeAll()
                return
            }
            Task {
                await model.makeRequests()
            }
        }
        .task {
            model.query = highlight.title
            await model.makeRequests()
        }
    }

    @ViewBuilder
    func SourceSection(result: SearchView.ResultGroup) -> some View {
        let data = result.result
        Section {
            ResultGroup(data.results, result.sourceID)
        } header: {
            HStack {
                Text(result.sourceName)
            }
            .padding(.horizontal)
        }
        .headerProminence(.increased)
        .alert("Confirm Link", isPresented: $isPresenting) {
            Button("Cancel", role: .cancel) {}
            Button("Link") {
                guard let selection else { return }
                Task {
                    let actor = await RealmActor()
                    let result = await actor.linkContent(id, selection.entry, selection.sourceId)
                    if result {
                        ToastManager.shared.info("Linked Contents!")
                    }
                }
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            if let selection {
                Text("Link \(selection.entry.title) to [\(result.sourceName)] \(highlight.title)")

            } else {
                EmptyView()
            }
        }
        .onChange(of: isPresenting) { newValue in
            if !newValue { selection = nil }
        }
    }

    @ViewBuilder
    func ResultGroup(_ result: [DSKCommon.Highlight], _ sourceId: String) -> some View {
        HStack {
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(result) { highlight in
                        DefaultTile(entry: highlight)
                            .frame(width: 150)
                            .onTapGesture {
                                handleSelection(highlight, sourceId)
                            }
                    }
                }
                .frame(height: CELL_HEIGHT)
                .padding(.leading)
            }
        }
    }

    var CELL_HEIGHT: CGFloat {
        (150 * 1.5) + (tileStyle == .SEPARATED ? 50 : 0)
        // Base + Title
    }

    var EmptyResults: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                Text("No Results.")
                    .font(.headline)
                    .fontWeight(.light)
            }
            Spacer()
        }
    }

    func handleSelection(_ h: DSKCommon.Highlight, _ s: String) {
        selection = (sourceId: s, entry: h)
        isPresenting.toggle()
    }
}
