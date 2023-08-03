////
////  ManualDestinationSelectionView.swift
////  Suwatte (iOS)
////
////  Created by Mantton on 2022-10-01.
////
//
//import SwiftUI
//
//struct ManualDestinationSelectionView: View {
//    var content: StoredContent
//    @Binding var states: [String: MigrationView.ItemState]
//    @StateObject private var model = SearchView.ViewModel()
//    @AppStorage(STTKeys.TileStyle) private var tileStyle = TileStyle.SEPARATED
//    @State private var isPresenting = false
//    @Environment(\.presentationMode) private var presentationMode
//    var body: some View {
//        List {
//            ForEach(model.sources.filter { $0.id != content.sourceId }, id: \.id) { source in
//                SourceCell(source: source)
//                    .listRowInsets(.init(top: 5, leading: 0, bottom: 20, trailing: 0))
//                    .listRowSeparator(.hidden)
//            }
//        }
//        .listStyle(.plain)
//        .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 0))
//        .navigationTitle("Select Match")
//        .navigationBarTitleDisplayMode(.inline)
//        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
//        .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main)) { val in
//            if val.isEmpty {
//                model.results.removeAll()
//                return
//            }
//            model.makeRequests()
//        }
//        .onAppear {
//            model.query = content.title
//        }
//        .navigationBarBackButtonHidden()
//        .toolbar {
//            ToolbarItem(placement: .cancellationAction) {
//                Button("Cancel", role: .cancel) {
//                    presentationMode.wrappedValue.dismiss()
//                }
//            }
//        }
//    }
//
//    @ViewBuilder
//    func SourceCell(source: StoredRunnerObject) -> some View {
//        let id = source.id
//        let data = model.results[id] ?? .loading
//        Section {
//            LoadableView(loadable: data) {
//                ResultGroup(DSKCommon.Highlight.placeholders(), id)
//                    .redacted(reason: .placeholder)
//            } _: {
//                ResultGroup(DSKCommon.Highlight.placeholders(), id)
//                    .redacted(reason: .placeholder)
//            } _: { error in
//                HStack {
//                    Spacer()
//                    ErrorView(error: error, runnerID: id, action: { model.loadForSource(id: id) })
//                    Spacer()
//                }
//            } _: { value in
//                if value.results.isEmpty {
//                    EmptyResults
//                } else {
//                    ResultGroup(value.results, id)
//                }
//            }
//        } header: {
//            HStack {
//                Text(source.name)
//            }
//            .padding(.horizontal)
//        }
//        .headerProminence(.increased)
//    }
//
//    @ViewBuilder
//    func ResultGroup(_ result: [DSKCommon.Highlight], _ sourceId: String) -> some View {
//        HStack {
//            ScrollView(.horizontal) {
//                LazyHStack {
//                    ForEach(result) { highlight in
//                        DefaultTile(entry: highlight)
//                            .frame(width: 150)
//                            .onTapGesture {
//                                handleSelection(highlight, sourceId)
//                            }
//                    }
//                }
//                .frame(height: CELL_HEIGHT)
//                .padding(.leading)
//            }
//        }
//    }
//
//    var CELL_HEIGHT: CGFloat {
//        (150 * 1.5) + (tileStyle == .SEPARATED ? 50 : 0)
//        // Base + Title
//    }
//
//    var EmptyResults: some View {
//        HStack {
//            Spacer()
//            VStack(alignment: .center) {
//                Text("No Results Matching Query")
//                    .font(.headline)
//                    .fontWeight(.light)
//                Text("Try Using a different query")
//                    .font(.subheadline)
//                    .fontWeight(.ultraLight)
//            }
//
//            Spacer()
//        }
//    }
//
//    func handleSelection(_ h: DSKCommon.Highlight, _ s: String) {
//        states[content.id] = .found((s, h))
//        isPresenting.toggle()
//    }
//}
